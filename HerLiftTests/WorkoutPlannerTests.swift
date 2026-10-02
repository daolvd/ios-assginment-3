import Foundation
import Testing
@testable import HerLift

@MainActor
struct WorkoutPlannerTests {
    // MARK: Flow

    @Test func eachTrainingDayGetsTheNextSessionGroupInWeekdayOrder() throws {
        let plan = try makeUseCase().execute(for: user(days: [5, 1, 3]))

        #expect(plan.workouts.map(\.weekday) == [1, 3, 5])
        #expect(plan.workouts.map(\.categoryIDs) == [["legs", "glutes"], ["back", "arms"], ["chest", "shoulders"]])
    }

    @Test func patternRestartsWhenThereAreMoreDaysThanGroups() throws {
        let useCase = makeUseCase(patterns: [pattern(groups: [["legs"], ["back"]])])
        let plan = try useCase.execute(for: user(days: [1, 2, 3, 4, 5]))

        #expect(plan.workouts.map(\.categoryIDs) == [["legs"], ["back"], ["legs"], ["back"], ["legs"]])
    }

    @Test func goalIsCarriedIntoThePlan() throws {
        let plan = try makeUseCase().execute(for: user(goalID: "buildMuscle"))
        #expect(plan.goalID == "buildMuscle")
    }

    // MARK: Covering every muscle group

    @Test func threeDayWeekAddsCoreToTheLastWorkout() throws {
        let useCase = makeUseCase(exercises: sampleCatalogue + [exercise("crunch", category: "core", minutes: 8)])
        let plan = try useCase.execute(for: user(days: [1, 3, 5]))

        #expect(plan.workouts.map(\.categoryIDs)
            == [["legs", "glutes"], ["back", "arms"], ["chest", "shoulders", "core"]])
        #expect(ids(plan.workouts[2]).contains("crunch"))
    }

    @Test func coreIsNotAddedAgainWhenTheWeekAlreadyHasIt() throws {
        let groups = [["legs", "glutes"], ["back", "arms"], ["chest", "shoulders"], ["glutes", "core"]]
        let useCase = makeUseCase(
            patterns: [pattern(groups: groups)],
            exercises: sampleCatalogue + [exercise("crunch", category: "core", minutes: 8)])
        let plan = try useCase.execute(for: user(days: [1, 2, 4, 6]))

        #expect(plan.workouts.map(\.categoryIDs) == groups)
    }

    @Test func coreIsNotAddedWhenNoEligibleCoreExerciseExists() throws {
        let floorOnly = exercise("crunch", category: "core", minutes: 8, tags: ["low-impact", "floor-based"])
        var profile = user(days: [1, 3, 5])
        profile.mustAvoidFloorExercises = true
        let useCase = makeUseCase(exercises: sampleCatalogue + [floorOnly])

        #expect(try useCase.execute(for: profile).workouts[2].categoryIDs == ["chest", "shoulders"])
        #expect(try useCase.execute(for: user(days: [1, 3, 5])).workouts[2].categoryIDs
            == ["chest", "shoulders", "core"])
    }

    // MARK: Filling a session

    @Test func everyCategoryGetsAnExerciseBeforeAnyGetsExtraSets() throws {
        // Both first picks fit at 3 sets, so they are chosen first and then raised to 5 sets each
        // (leg-press 20 min + glute-bridge 16.7 min = 36.7). No further exercise fits in the 45 minutes.
        let workout = try makeUseCase().execute(for: user(days: [1, 2], minutes: 45)).workouts[0]

        #expect(ids(workout) == ["leg-press", "glute-bridge"])
        #expect(workout.exercises.map(\.sets) == [5, 5])
        #expect(workout.estimatedMinutes == 37)
    }

    @Test func extraSetsComeBeforeExtraExercisesAndTooLongExercisesAreSkipped() throws {
        // legs: 20, 30 and 10 minutes at 3 sets. The first exercise grows to 5 sets (33.3 min);
        // the 30-minute exercise cannot fit, the 10-minute one can (43.3 min).
        let catalogue = [
            exercise("a1", category: "legs", minutes: 20),
            exercise("a2", category: "legs", minutes: 30),
            exercise("a3", category: "legs", minutes: 10),
        ]
        let useCase = makeUseCase(patterns: [pattern(groups: [["legs"]])], exercises: catalogue)
        let workout = try useCase.execute(for: user(days: [1], minutes: 45)).workouts[0]

        #expect(ids(workout) == ["a1", "a3"])
        #expect(workout.exercises.map(\.sets) == [5, 3])
        #expect(workout.estimatedMinutes == 44)
    }

    @Test func aWorkoutMayFillTheSessionExactly() throws {
        // 12 minutes at 3 sets is 4 minutes per set, so 5 sets is exactly 20 minutes.
        let catalogue = [exercise("a1", category: "legs", minutes: 12)]
        let useCase = makeUseCase(patterns: [pattern(groups: [["legs"]])], exercises: catalogue)
        let workout = try useCase.execute(for: user(days: [1], minutes: 20)).workouts[0]

        #expect(workout.exercises.map(\.sets) == [5])
        #expect(workout.estimatedMinutes == 20)
    }

    @Test func noWorkoutIsLongerThanTheChosenSessionLength() throws {
        for dayCount in 1...7 {
            for minutes in [45, 60, 75] {
                let plan = try makeUseCase().execute(for: user(days: Array(1...dayCount), minutes: minutes))
                #expect(plan.workouts.allSatisfy { $0.estimatedMinutes <= minutes })
                #expect(plan.workouts.allSatisfy { !$0.exercises.isEmpty })
            }
        }
    }

    @Test func bundledCatalogueProducesAValidPlanForEveryDayCountAndSessionLength() throws {
        let useCase = CreateWorkoutPlanUseCase(
            patterns: try JSONTrainingPatternRepository(), exercises: try JSONExerciseRepository())
        for dayCount in 1...7 {
            for minutes in [30, 45, 60, 75, 90] {
                let plan = try useCase.execute(for: user(days: Array(1...dayCount), minutes: minutes))
                #expect(plan.workouts.count == dayCount)
                #expect(plan.workouts.allSatisfy { !$0.exercises.isEmpty && $0.estimatedMinutes <= minutes })
                #expect(plan.workouts.flatMap(\.exercises).allSatisfy { (3...5).contains($0.sets) })
            }
        }
    }

    @Test func bundledCatalogueCoversEveryMuscleGroupInAThreeDayWeek() throws {
        let useCase = CreateWorkoutPlanUseCase(
            patterns: try JSONTrainingPatternRepository(), exercises: try JSONExerciseRepository())
        let plan = try useCase.execute(for: user(days: [1, 3, 5], minutes: 60))
        let trained = Set(plan.workouts.flatMap(\.exercises).map(\.exercise.categoryID))

        #expect(trained == ["legs", "glutes", "back", "arms", "chest", "shoulders", "core"])
    }

    // MARK: Filters

    @Test func avoidFloorExercisesRemovesFloorBasedOnes() throws {
        var profile = user(days: [1, 2])
        profile.mustAvoidFloorExercises = true
        let plan = try makeUseCase().execute(for: profile)

        #expect(!plan.workouts.flatMap(\.exercises).contains { $0.exercise.tagIDs.contains("floor-based") })
        #expect(ids(plan.workouts[0]).contains("glute-kickback"))
    }

    @Test func requireLowImpactRemovesExercisesWithoutTheTag() throws {
        let catalogue = [
            exercise("jump", category: "legs", minutes: 10, tags: []),
            exercise("press", category: "legs", minutes: 10, tags: ["low-impact"]),
        ]
        var profile = user(days: [1])
        profile.requiresLowImpact = true
        let useCase = makeUseCase(patterns: [pattern(groups: [["legs"]])], exercises: catalogue)

        #expect(ids(try useCase.execute(for: profile).workouts[0]) == ["press"])
    }

    @Test func personNeverGetsExercisesAboveTheirLevel() throws {
        let catalogue = [
            exercise("easy", category: "legs", minutes: 10, level: "beginner"),
            exercise("hard", category: "legs", minutes: 10, level: "intermediate"),
        ]
        let useCase = makeUseCase(patterns: [pattern(groups: [["legs"]])], exercises: catalogue)

        #expect(ids(try useCase.execute(for: user(days: [1], level: .beginner)).workouts[0]) == ["easy"])
        #expect(ids(try useCase.execute(for: user(days: [1], level: .intermediate)).workouts[0]) == ["easy", "hard"])
    }

    @Test func intermediateLevelUsesTheBeginnerPatternWhenNothingHigherExists() throws {
        let plan = try makeUseCase().execute(for: user(days: [1], level: .intermediate))
        #expect(plan.workouts[0].categoryIDs == ["legs", "glutes"])
    }

    // MARK: Errors

    @Test func invalidTrainingDaysAreRejected() {
        let useCase = makeUseCase()
        for days in [[], [1, 1], [0, 2], [2, 8], Array(1...7) + [1]] {
            #expect(throws: PlanningError.unsupportedTrainingDays) { try useCase.execute(for: user(days: days)) }
        }
    }

    @Test func sessionLengthOutsideTheSupportedRangeIsRejected() {
        let useCase = makeUseCase()
        for minutes in [0, 15, 125] {
            #expect(throws: PlanningError.unsupportedSessionMinutes) { try useCase.execute(for: user(minutes: minutes)) }
        }
    }

    @Test func missingPatternThrowsPatternNotFound() {
        #expect(throws: PlanningError.patternNotFound) {
            try makeUseCase(patterns: []).execute(for: user())
        }
        #expect(throws: PlanningError.patternNotFound) {
            try makeUseCase(patterns: [pattern(groups: [])]).execute(for: user())
        }
    }

    @Test func categoryWithNoEligibleExerciseLeavesAnEmptyWorkoutAndFailsValidation() {
        let useCase = makeUseCase(patterns: [pattern(groups: [["core"]])])
        #expect(throws: PlanningError.emptyWorkout) { try useCase.execute(for: user(days: [1])) }
    }

    // MARK: Validator

    @Test func validatorRejectsEachKindOfBrokenPlan() {
        let validator = WorkoutPlanValidator()
        let profile = user(days: [1], minutes: 45)
        let ok = planned(exercise("ok", category: "legs", minutes: 10))

        func plan(_ workout: PlannedWorkout, count: Int = 1) -> WorkoutPlan {
            WorkoutPlan(goalID: "g", workouts: Array(repeating: workout, count: count))
        }
        func workout(
            categories: [String] = ["legs"], exercises: [PlannedExercise]? = nil, minutes: Int = 30
        ) -> PlannedWorkout {
            PlannedWorkout(weekday: 1, categoryIDs: categories, exercises: exercises ?? [ok], estimatedMinutes: minutes)
        }

        #expect(throws: Never.self) { try validator.validate(plan(workout()), for: profile) }
        #expect(throws: Never.self) {
            try validator.validate(plan(workout(categories: ["legs", "glutes", "core"])), for: profile)
        }
        #expect(throws: PlanningError.invalidSessionCount) { try validator.validate(plan(workout(), count: 2), for: profile) }
        #expect(throws: PlanningError.tooManyCategories) {
            try validator.validate(plan(workout(categories: ["legs", "glutes", "back"])), for: profile)
        }
        #expect(throws: PlanningError.emptyWorkout) { try validator.validate(plan(workout(exercises: [])), for: profile) }
        #expect(throws: PlanningError.sessionTooLong) { try validator.validate(plan(workout(minutes: 46)), for: profile) }
        #expect(throws: PlanningError.invalidSetCount) {
            try validator.validate(plan(workout(exercises: [planned(ok.exercise, sets: 6)])), for: profile)
        }
        #expect(throws: PlanningError.invalidExerciseCategory) {
            let other = planned(exercise("x", category: "back", minutes: 10))
            try validator.validate(plan(workout(exercises: [other])), for: profile)
        }
        #expect(throws: PlanningError.invalidExerciseLevel) {
            let hard = planned(exercise("x", category: "legs", minutes: 10, level: "intermediate"))
            try validator.validate(plan(workout(exercises: [hard])), for: profile)
        }
    }

    // MARK: Onboarding mapping

    @Test func onboardingAnswersMapToPlannerInput() {
        let profile = OnboardingProfile(
            age: 30, heightCm: 165, weightKg: 60, experience: .some, trainingWeekdays: [2, 4],
            sessionMinutes: 60, healthNote: "Knee pain", clearedByDoctor: false)
        let mapped = UserPlanningProfile(profile: profile, goalID: "loseFat")

        #expect(mapped == UserPlanningProfile(level: .intermediate, goalID: "loseFat", trainingDays: [2, 4], sessionMinutes: 60))
    }
}

// MARK: - Helpers

private func ids(_ workout: PlannedWorkout) -> [String] { workout.exercises.map(\.id) }

private func user(
    days: [Int] = [1, 3, 5], minutes: Int = 45, level: TrainingLevel = .beginner, goalID: String = "buildMuscle"
) -> UserPlanningProfile {
    UserPlanningProfile(level: level, goalID: goalID, trainingDays: days, sessionMinutes: minutes)
}

private func pattern(groups: [[String]]) -> TrainingPattern {
    TrainingPattern(
        id: "test", title: "Test", level: .beginner, description: "",
        sessionGroups: groups.enumerated().map { TrainingPatternSession(id: "g\($0.offset)", categoryIDs: $0.element) })
}

private func planned(_ exercise: Exercise, sets: Int = 3) -> PlannedExercise {
    PlannedExercise(exercise: exercise, sets: sets)
}

private func exercise(
    _ id: String, category: String, minutes: Int, level: String = "beginner", tags: [String] = ["low-impact"]
) -> Exercise {
    Exercise(
        id: id, name: id, muscleGroup: category, primaryMuscle: "", secondaryMuscles: [], equipment: "machine",
        level: level, loadType: "external", position: "seated", impact: "low", minimumReps: 10, maximumReps: 12,
        defaultRestSeconds: 60, shortDescription: "", instructions: [], coachingCues: [], commonMistakes: [],
        breathing: "", alternativeExerciseIDs: [], videoFile: nil, imageURL: nil, videoURL: nil, source: nil,
        categoryID: category, tagIDs: tags, estimatedMinutes: minutes)
}

/// Small fixed catalogue so expected results can be read straight off the page.
private let sampleCatalogue = [
    exercise("leg-press", category: "legs", minutes: 12),
    exercise("leg-extension", category: "legs", minutes: 10),
    exercise("goblet-squat", category: "legs", minutes: 12),
    exercise("glute-bridge", category: "glutes", minutes: 10, tags: ["low-impact", "floor-based"]),
    exercise("glute-kickback", category: "glutes", minutes: 10),
    exercise("lat-pulldown", category: "back", minutes: 12),
    exercise("biceps-curl", category: "arms", minutes: 10),
    exercise("chest-press", category: "chest", minutes: 12),
    exercise("shoulder-press", category: "shoulders", minutes: 12),
]

private func makeUseCase(
    patterns: [TrainingPattern]? = nil, exercises: [Exercise]? = nil
) -> CreateWorkoutPlanUseCase {
    let defaultPattern = pattern(groups: [["legs", "glutes"], ["back", "arms"], ["chest", "shoulders"]])
    return CreateWorkoutPlanUseCase(
        patterns: PatternRepositoryStub(patterns: patterns ?? [defaultPattern]),
        exercises: ExerciseRepositoryStub(exercises: exercises ?? sampleCatalogue))
}

@MainActor
private struct PatternRepositoryStub: TrainingPatternRepository {
    let patterns: [TrainingPattern]
    func load() throws -> [TrainingPattern] { patterns }
}

@MainActor
private struct ExerciseRepositoryStub: ExerciseRepository {
    let exercises: [Exercise]
    func load() throws -> [Exercise] { exercises }
    func exercise(id: String) -> Exercise? { exercises.first { $0.id == id } }
    func videoURL(for exercise: Exercise) -> URL? { nil }
}
