import Foundation
import Testing
@testable import HerLift

// MARK: - The starting-weight table

@MainActor
struct StartingWeightTableTests {
    private let table = try! JSONStartingWeightRepository().table
    private let catalogue = try! JSONExerciseRepository()

    private func exercise(_ id: String) -> Exercise { catalogue.exercise(id: id)! }

    /// A woman of 165 cm; `weightKg` sets her BMI (60 kg ≈ 22).
    private func user(
        level: TrainingLevel = .beginner, age: Int? = 29, weightKg: Double? = 60, heightCm: Double? = 165,
        healthConcern: Bool = false
    ) -> UserPlanningProfile {
        UserPlanningProfile(
            level: level, goalID: "buildMuscle", trainingDays: [1, 3, 5], sessionMinutes: 45,
            reportsHealthConcern: healthConcern, clearedByDoctor: healthConcern, age: age, weightKg: weightKg,
            heightCm: heightCm)
    }

    @Test func everyExerciseWithAWeightHasAFullRowForEveryGroup() {
        for exercise in catalogue.exercises where exercise.loadType != "bodyweight" {
            let byLevel = table.weights[exercise.id]
            #expect(byLevel != nil, "\(exercise.id) is missing")
            for level in ["beginner", "intermediate"] {
                for band in table.ageBands {
                    let row = byLevel?[level]?[band.id] ?? []
                    #expect(row.count == table.bmiBands.count, "\(exercise.id) \(level) \(band.id)")
                    let step = table.stepKg[exercise.equipment] ?? 1
                    for kg in row {
                        #expect(kg > 0)
                        #expect((kg / step).rounded() * step == kg, "\(exercise.id) \(kg) kg is not a step of \(step)")
                    }
                }
            }
        }
    }

    @Test func bodyweightExercisesHaveNoWeight() {
        #expect(table.weights["glute-bridge"] == nil)
        #expect(table.kg(for: exercise("glute-bridge"), user: user()) == nil)
        #expect(table.kg(for: exercise("reverse-crunch"), user: user()) == nil)
    }

    @Test func aYoungBeginnerWithAHealthyBMIStartsFromTheAnchorWeights() {
        #expect(table.kg(for: exercise("leg-press"), user: user()) == 30)
        #expect(table.kg(for: exercise("machine-chest-press"), user: user()) == 10)
        #expect(table.kg(for: exercise("dumbbell-lateral-raise"), user: user()) == 2)
    }

    @Test func experienceStartsHeavier() {
        let beginner = table.kg(for: exercise("lat-pulldown"), user: user())!
        let experienced = table.kg(for: exercise("lat-pulldown"), user: user(level: .intermediate))!

        #expect(experienced > beginner)
    }

    @Test func olderAgeBandsStartLighter() {
        let young = table.kg(for: exercise("leg-press"), user: user(age: 29))!
        let middle = table.kg(for: exercise("leg-press"), user: user(age: 45))!
        let older = table.kg(for: exercise("leg-press"), user: user(age: 60))!

        #expect(young > middle)
        #expect(middle > older)
    }

    @Test func theBMIBandsFollowHerHeightAndWeight() {
        // 165 cm: 48 kg ≈ BMI 17.6, 60 kg ≈ 22, 75 kg ≈ 27.5, 90 kg ≈ 33.
        #expect(table.kg(for: exercise("leg-press"), user: user(weightKg: 48)) == 25)
        #expect(table.kg(for: exercise("leg-press"), user: user(weightKg: 60)) == 30)
        #expect(table.kg(for: exercise("leg-press"), user: user(weightKg: 75)) == 30)
        #expect(table.kg(for: exercise("leg-press"), user: user(weightKg: 90)) == 25)
    }

    @Test func aHealthConcernClearedByADoctorStartsLighterRoundedDown() {
        // 30 kg × 0.85 = 25.5 kg, down to the machine's 2.5 kg step.
        #expect(table.kg(for: exercise("leg-press"), user: user(healthConcern: true)) == 25)
    }

    @Test func noWeightGoesBelowTheEquipmentsSmallest() {
        let lightest = user(age: 70, weightKg: 45, healthConcern: true)

        #expect(table.kg(for: exercise("dumbbell-lateral-raise"), user: lightest) == 1)
        #expect(table.kg(for: exercise("rope-rear-delt-row"), user: lightest)! >= 2.5)
    }

    @Test func unknownAgeAndMeasurementsUseTheYoungestBandAndATypicalBMI() {
        let unknown = user(age: nil, weightKg: nil, heightCm: nil)

        #expect(table.kg(for: exercise("leg-press"), user: unknown) == 30)
    }
}

// MARK: - A new plan starts with these weights

@MainActor
struct PlanStartingWeightTests {
    @Test func aNewPlanGivesEveryWeightedExerciseItsStartingWeight() throws {
        let exercises = try JSONExerciseRepository()
        let startingWeights = try JSONStartingWeightRepository()
        let useCase = CreateWorkoutPlanUseCase(
            patterns: try JSONTrainingPatternRepository(), exercises: exercises, plans: PlanStoreStub(),
            startingWeights: startingWeights)
        let user = UserPlanningProfile(
            level: .beginner, goalID: "buildMuscle", trainingDays: [1, 3, 5], sessionMinutes: 60, age: 29,
            weightKg: 60, heightCm: 165)

        let plan = try useCase.execute(for: user)

        let planned = plan.workouts.flatMap(\.exercises)
        #expect(!planned.isEmpty)
        for item in planned {
            if item.exercise.loadType == "bodyweight" {
                #expect(item.targetWeightKg == nil)
            } else {
                #expect(item.targetWeightKg == startingWeights.table.kg(for: item.exercise, user: user))
                #expect(item.targetWeightKg != nil)
            }
        }
    }

    @Test func withoutTheTableExercisesStartWithoutAWeight() throws {
        let useCase = CreateWorkoutPlanUseCase(
            patterns: try JSONTrainingPatternRepository(), exercises: try JSONExerciseRepository(),
            plans: PlanStoreStub())
        let user = UserPlanningProfile(level: .beginner, goalID: "buildMuscle", trainingDays: [1, 3, 5], sessionMinutes: 60)

        let plan = try useCase.execute(for: user)

        #expect(plan.workouts.flatMap(\.exercises).allSatisfy { $0.targetWeightKg == nil })
    }
}
