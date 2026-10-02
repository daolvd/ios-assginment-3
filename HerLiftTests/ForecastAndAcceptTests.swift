import Foundation
import SwiftData
import Testing
@testable import HerLift

// MARK: - Forecast numbers

struct ForecastCalculatorTests {
    @Test func fatLossWeeksRunFromOneKilogramAWeekToHalfAKilogramAWeek() throws {
        // 62 kg to 56 kg is 6 kg: 6 weeks at 1 kg a week, 12 weeks at 0.5 kg a week.
        let forecast = try ForecastCalculator.weightLossForecast(for: loseFat(current: 62, target: 56))

        #expect(forecast == WeightLossForecast(currentKg: 62, targetKg: 56, earliestWeek: 6, latestWeek: 12))
    }

    @Test func partialWeeksRoundUp() throws {
        let forecast = try ForecastCalculator.weightLossForecast(for: loseFat(current: 62, target: 54.7))
        #expect(forecast?.earliestWeek == 8)
        #expect(forecast?.latestWeek == 15)
    }

    @Test func aSmallLossStillTakesAtLeastOneWeek() throws {
        let forecast = try ForecastCalculator.weightLossForecast(for: loseFat(current: 62, target: 61.8))
        #expect(forecast?.earliestWeek == 1)
        #expect(forecast?.latestWeek == 1)
    }

    @Test func otherGoalsHaveNoWeightForecast() throws {
        var profile = loseFat(current: 62, target: 56)
        for goalID in ["buildMuscle", "buildStrength", "increaseGymConfidence"] {
            profile = UserPlanningProfile(
                level: .beginner, goalID: goalID, trainingDays: [1, 3], sessionMinutes: 45,
                weightKg: 62, heightCm: 165, targetWeightKg: nil)
            #expect(try ForecastCalculator.weightLossForecast(for: profile) == nil)
        }
    }

    @Test func aTargetBelowAHealthyBodyMassIndexIsRefusedWithTheLowestSafeWeight() {
        // 165 cm: a body mass index of 18.5 is 50.4 kg, so the lowest whole-kilogram target is 51.
        #expect(throws: PlanningError.unsafeTargetWeight(minimumKg: 51)) {
            try ForecastCalculator.weightLossForecast(for: loseFat(current: 62, target: 45))
        }
        #expect(throws: PlanningError.unsafeTargetWeight(minimumKg: 51)) {
            try ForecastCalculator.weightLossForecast(for: loseFat(current: 62, target: 50.3))
        }
        #expect(throws: Never.self) { try ForecastCalculator.weightLossForecast(for: loseFat(current: 62, target: 50.4)) }
        #expect(ForecastCalculator.minimumHealthyWeightKg(heightCm: 165) == 51)
        #expect(ForecastCalculator.minimumHealthyWeightKg(heightCm: 150) == 42)
    }

    @Test func theTargetMustBeBelowTheCurrentWeight() {
        for target in [62.0, 70] {
            #expect(throws: PlanningError.targetNotBelowCurrent) {
                try ForecastCalculator.weightLossForecast(for: loseFat(current: 62, target: target))
            }
        }
    }

    @Test func fatLossNeedsATargetAndTheBodyMeasurements() {
        var profile = loseFat(current: 62, target: 56)
        profile.targetWeightKg = nil
        #expect(throws: PlanningError.targetWeightRequired) { try ForecastCalculator.weightLossForecast(for: profile) }
        profile = loseFat(current: 62, target: 56)
        profile.heightCm = nil
        #expect(throws: PlanningError.targetWeightRequired) { try ForecastCalculator.weightLossForecast(for: profile) }
    }

    @Test func eachGoalHasItsMilestones() {
        func weeks(_ goalID: String) -> [Int] { ForecastCalculator.milestones(for: goalID).map(\.startWeek) }

        #expect(weeks("loseFat") == [1, 4, 12])
        #expect(weeks("buildMuscle") == [1, 3, 8, 12])
        #expect(weeks("buildStrength") == [1, 3, 8, 12])
        #expect(weeks("increaseGymConfidence") == [1, 4])
        #expect(weeks("unknown").isEmpty)
        #expect(ForecastCalculator.milestones(for: "buildMuscle")[1].endWeek == 6)
    }

    @Test func theDisclaimerIsTheApprovedWording() {
        #expect(ForecastCalculator.disclaimer
            == "Dự đoán — giả định bạn tập đều theo kế hoạch và kiểm soát ăn uống. Kết quả thực tế có thể khác.")
    }
}

// MARK: - Creating a plan with a forecast

@MainActor
struct CreatePlanForecastTests {
    @Test func aFatLossPlanCarriesItsForecastAndIsStoredAsADraft() throws {
        let store = PlanStoreStub()
        let plan = try makeCreate(store).execute(for: loseFat(current: 62, target: 56))

        #expect(plan.status == .draft)
        #expect(plan.weightForecast == WeightLossForecast(currentKg: 62, targetKg: 56, earliestWeek: 6, latestWeek: 12))
        #expect(plan.startedOn == nil)
        #expect(store.plan == plan)
    }

    @Test func otherGoalsGetNoWeightForecast() throws {
        let profile = UserPlanningProfile(
            level: .beginner, goalID: "buildMuscle", trainingDays: [1, 3], sessionMinutes: 45)
        #expect(try makeCreate(PlanStoreStub()).execute(for: profile).weightForecast == nil)
    }

    @Test func anUnsafeTargetBuildsNoPlanAndKeepsTheStoredOne() {
        let earlier = WorkoutPlan(goalID: "old", workouts: [])
        let store = PlanStoreStub(plan: earlier)

        #expect(throws: PlanningError.unsafeTargetWeight(minimumKg: 51)) {
            try makeCreate(store).execute(for: loseFat(current: 62, target: 45))
        }
        #expect(store.plan == earlier)
    }

    private func makeCreate(_ store: PlanStoreStub) -> CreateWorkoutPlanUseCase {
        CreateWorkoutPlanUseCase(
            patterns: try! JSONTrainingPatternRepository(), exercises: try! JSONExerciseRepository(), plans: store)
    }
}

// MARK: - Accepting a plan and starting over

@MainActor
struct AcceptPlanTests {
    private let now = Date(timeIntervalSince1970: 1_790_000_000 + 13 * 3600) // some time during a day

    @Test func acceptingADraftMakesItActiveFromTheStartOfToday() throws {
        let store = PlanStoreStub(plan: draftPlan())

        let accepted = try makeUseCase(store).acceptPlan(now: now)

        #expect(accepted.status == .active)
        #expect(accepted.startedOn == Calendar.current.startOfDay(for: now))
        #expect(store.plan == accepted)
        #expect(accepted.workouts == draftPlan().workouts)
    }

    @Test func aPlanCanOnlyBeAcceptedOnce() throws {
        let store = PlanStoreStub(plan: draftPlan())
        let useCase = makeUseCase(store)
        let accepted = try useCase.acceptPlan(now: now)

        #expect(throws: WorkoutPlanError.planAlreadyAccepted) { try useCase.acceptPlan(now: now) }
        #expect(store.plan == accepted)
    }

    @Test func acceptingWithoutAPlanThrowsNoPlan() {
        #expect(throws: WorkoutPlanError.noPlan) { try makeUseCase(PlanStoreStub()).acceptPlan(now: now) }
    }

    @Test func aStorageFailureKeepsThePlanAsADraft() {
        let store = PlanStoreStub(plan: draftPlan())
        store.failsOnSave = true

        #expect(throws: WorkoutPlanError.couldNotAcceptPlan) { try makeUseCase(store).acceptPlan(now: now) }
        #expect(store.plan?.status == .draft)
    }

    @Test func editingKeepsTheStatusAndTheForecast() throws {
        var plan = draftPlan()
        plan.weightForecast = WeightLossForecast(currentKg: 62, targetKg: 56, earliestWeek: 6, latestWeek: 12)
        let store = PlanStoreStub(plan: plan)
        let useCase = makeUseCase(store)
        _ = try useCase.acceptPlan(now: now)

        let edited = try useCase.execute(
            .setSets(weekday: 1, exerciseID: "leg-press", sets: 4),
            for: UserPlanningProfile(level: .beginner, goalID: "loseFat", trainingDays: [1, 3], sessionMinutes: 90))

        #expect(edited.status == .active)
        #expect(edited.startedOn == Calendar.current.startOfDay(for: now))
        #expect(edited.weightForecast == plan.weightForecast)
    }

    @Test func startingOverDeletesThePlan() throws {
        let store = PlanStoreStub(plan: draftPlan())
        try makeUseCase(store).deletePlan()
        #expect(store.plan == nil)
    }

    @Test func statusForecastAndStartDateSurviveTheSwiftDataStore() throws {
        let schema = Schema([TrainingPlan.self, WorkoutDay.self, PlannedExercise.self])
        let container = try ModelContainer(
            for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
        let repository = SwiftDataWorkoutPlanRepository(
            modelContext: ModelContext(container), exercises: try JSONExerciseRepository())
        var plan = draftPlan()
        plan.weightForecast = WeightLossForecast(currentKg: 62, targetKg: 56, earliestWeek: 6, latestWeek: 12)
        try repository.savePlan(plan)
        #expect(try repository.loadPlan() == plan)

        plan.status = .active
        plan.startedOn = Calendar.current.startOfDay(for: now)
        try repository.savePlan(plan)
        #expect(try repository.loadPlan() == plan)
    }

    private func makeUseCase(_ store: PlanStoreStub) -> EditWorkoutPlanUseCase {
        EditWorkoutPlanUseCase(plans: store, exercises: try! JSONExerciseRepository())
    }

    /// Two workouts built from the bundled catalogue.
    private func draftPlan() -> WorkoutPlan {
        let catalogue = try! JSONExerciseRepository().exercises
        func planned(_ id: String) -> WorkoutExercise {
            WorkoutExercise(exercise: catalogue.first { $0.id == id }!, sets: 3)
        }
        return WorkoutPlan(goalID: "loseFat", workouts: [
            PlannedWorkout(weekday: 1, categoryIDs: ["legs", "glutes"], exercises: [planned("leg-press"), planned("glute-bridge")]),
            PlannedWorkout(weekday: 3, categoryIDs: ["back"], exercises: [planned("lat-pulldown")]),
        ])
    }
}

private func loseFat(current: Double, target: Double) -> UserPlanningProfile {
    UserPlanningProfile(
        level: .beginner, goalID: "loseFat", trainingDays: [1, 3, 5], sessionMinutes: 45,
        weightKg: current, heightCm: 165, targetWeightKg: target)
}
