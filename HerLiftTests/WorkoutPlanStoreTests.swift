import Foundation
import SwiftData
import Testing
@testable import HerLift

// MARK: - Editing a plan (pure)

@MainActor
struct WorkoutPlanEditorTests {
    private let editor = WorkoutPlanEditor(catalogue: catalogue)

    @Test func removeTakesTheExerciseOutAndShortensTheWorkout() throws {
        let edited = try editor.apply(.removeExercise(weekday: 1, exerciseID: "kickback"), to: plan(), for: user())

        #expect(ids(edited, weekday: 1) == ["press"])
        #expect(edited.workouts[0].estimatedMinutes == 12)
        #expect(ids(edited, weekday: 3) == ["pulldown"])
    }

    @Test func aWorkoutKeepsAtLeastOneExercise() {
        #expect(throws: WorkoutPlanError.cannotRemoveLastExercise) {
            try editor.apply(.removeExercise(weekday: 3, exerciseID: "pulldown"), to: plan(), for: user())
        }
    }

    @Test func unknownWorkoutOrExerciseIsRejected() {
        #expect(throws: WorkoutPlanError.workoutNotFound) {
            try editor.apply(.removeExercise(weekday: 2, exerciseID: "press"), to: plan(), for: user())
        }
        #expect(throws: WorkoutPlanError.exerciseNotFound) {
            try editor.apply(.removeExercise(weekday: 1, exerciseID: "pulldown"), to: plan(), for: user())
        }
    }

    @Test func moveReordersWithinTheWorkout() throws {
        let edited = try editor.apply(.moveExercise(weekday: 1, exerciseID: "kickback", toIndex: 0), to: plan(), for: user())
        #expect(ids(edited, weekday: 1) == ["kickback", "press"])
    }

    @Test func moveToAPositionOutsideTheWorkoutIsRejected() {
        for index in [-1, 2] {
            #expect(throws: WorkoutPlanError.invalidPosition) {
                try editor.apply(.moveExercise(weekday: 1, exerciseID: "press", toIndex: index), to: plan(), for: user())
            }
        }
    }

    @Test func setsCanBeChangedBetweenOneAndFive() throws {
        let edited = try editor.apply(.setSets(weekday: 1, exerciseID: "press", sets: 5), to: plan(), for: user())
        #expect(edited.workouts[0].exercises.map(\.sets) == [5, 3])
        for sets in [0, 6] {
            #expect(throws: WorkoutPlanError.invalidSetCount) {
                try editor.apply(.setSets(weekday: 1, exerciseID: "press", sets: sets), to: plan(), for: user())
            }
        }
    }

    @Test func moreSetsAreRejectedWhenTheyDoNotFitTheSessionLength() {
        // 12 + 10 = 22 minutes now; press at 5 sets would make 20 + 10 = 30 minutes.
        #expect(throws: WorkoutPlanError.notEnoughTime) {
            try editor.apply(.setSets(weekday: 1, exerciseID: "press", sets: 5), to: plan(), for: user(minutes: 25))
        }
    }

    @Test func addAppendsAnEligibleExerciseWithTheBaselineSets() throws {
        let edited = try editor.apply(.addExercise(weekday: 1, exerciseID: "extension"), to: plan(), for: user())

        #expect(ids(edited, weekday: 1) == ["press", "kickback", "extension"])
        #expect(edited.workouts[0].exercises.last?.sets == 3)
        #expect(edited.workouts[0].estimatedMinutes == 32)
    }

    @Test func addRejectsExercisesThatDoNotSuitTheWorkout() {
        func add(_ id: String, as profile: UserPlanningProfile = user()) throws {
            _ = try editor.apply(.addExercise(weekday: 1, exerciseID: id), to: plan(), for: profile)
        }
        #expect(throws: WorkoutPlanError.exerciseNotFound) { try add("nonexistent") }
        #expect(throws: WorkoutPlanError.exerciseAlreadyInWorkout) { try add("press") }
        #expect(throws: WorkoutPlanError.exerciseNotAllowed) { try add("curl") } // arms is not in this workout
        var avoidFloor = user()
        avoidFloor.mustAvoidFloorExercises = true
        #expect(throws: WorkoutPlanError.exerciseNotAllowed) { try add("bridge", as: avoidFloor) }
        #expect(throws: Never.self) { try add("bridge") }
        #expect(throws: WorkoutPlanError.notEnoughTime) { try add("extension", as: user(minutes: 25)) }
    }

    @Test func aPlanThatNoLongerMatchesTheProfileFailsTheFinalCheck() {
        #expect(throws: WorkoutPlanError.invalidPlan) {
            try editor.apply(.moveExercise(weekday: 1, exerciseID: "press", toIndex: 1), to: plan(), for: user(days: [1, 3, 5]))
        }
    }
}

// MARK: - Storing a plan (SwiftData, in memory)

@MainActor
struct SwiftDataWorkoutPlanRepositoryTests {
    @Test func savedPlanComesBackWithTheSameOrder() throws {
        let (repository, _) = try makeRepository()
        let reordered = WorkoutPlan(goalID: "buildMuscle", workouts: [
            PlannedWorkout(weekday: 3, categoryIDs: ["back"], exercises: [planned("pulldown", sets: 4)]),
            PlannedWorkout(weekday: 1, categoryIDs: ["legs", "glutes"],
                           exercises: [planned("kickback", sets: 5), planned("press", sets: 3)]),
        ])

        try repository.savePlan(reordered)

        #expect(try repository.loadPlan() == reordered)
    }

    @Test func nothingStoredLoadsAsNil() throws {
        #expect(try makeRepository().0.loadPlan() == nil)
    }

    @Test func savingAgainReplacesThePreviousPlan() throws {
        let (repository, context) = try makeRepository()
        try repository.savePlan(plan())
        let second = WorkoutPlan(goalID: "loseFat", workouts: [
            PlannedWorkout(weekday: 2, categoryIDs: ["back"], exercises: [planned("pulldown")])
        ])
        try repository.savePlan(second)

        #expect(try repository.loadPlan() == second)
        #expect(try context.fetchCount(FetchDescriptor<TrainingPlan>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<WorkoutDay>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<PlannedExercise>()) == 1)
    }

    @Test func deletingRemovesThePlanAndEverythingInIt() throws {
        let (repository, context) = try makeRepository()
        try repository.savePlan(plan())

        try repository.deletePlan()

        #expect(try repository.loadPlan() == nil)
        #expect(try context.fetchCount(FetchDescriptor<WorkoutDay>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<PlannedExercise>()) == 0)
        #expect(throws: Never.self) { try repository.deletePlan() }
    }

    @Test func planWithAnExerciseMissingFromTheCatalogueCannotBeLoaded() throws {
        let (repository, context) = try makeRepository()
        try repository.savePlan(plan())
        let smaller = SwiftDataWorkoutPlanRepository(
            modelContext: context, exercises: ExerciseCatalogueStub(exercises: catalogue.filter { $0.id != "kickback" }))

        #expect(throws: (any Error).self) { try smaller.loadPlan() }
    }

    private func makeRepository() throws -> (SwiftDataWorkoutPlanRepository, ModelContext) {
        let schema = Schema([TrainingPlan.self, WorkoutDay.self, PlannedExercise.self])
        let container = try ModelContainer(
            for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        keepAlive.append(container)
        return (SwiftDataWorkoutPlanRepository(modelContext: context, exercises: ExerciseCatalogueStub(exercises: catalogue)), context)
    }
}

// MARK: - Use case

@MainActor
struct EditWorkoutPlanUseCaseTests {
    @Test func currentPlanReturnsTheStoredPlanNilWhenThereIsNoneAndReportsFailures() throws {
        let store = PlanStoreStub()
        let useCase = makeUseCase(store)
        #expect(try useCase.currentPlan() == nil)

        store.plan = plan()
        #expect(try useCase.currentPlan() == plan())

        store.fails = true
        #expect(throws: WorkoutPlanError.couldNotLoadPlan) { try useCase.currentPlan() }
    }

    @Test func editChangesAndStoresTheCurrentPlan() throws {
        let store = PlanStoreStub(plan: plan())

        let edited = try makeUseCase(store).execute(.setSets(weekday: 1, exerciseID: "press", sets: 4), for: user())

        #expect(edited.workouts[0].exercises.map(\.sets) == [4, 3])
        #expect(store.plan == edited)
    }

    @Test func aRejectedEditLeavesTheStoredPlanUntouched() {
        let store = PlanStoreStub(plan: plan())

        #expect(throws: WorkoutPlanError.cannotRemoveLastExercise) {
            try makeUseCase(store).execute(.removeExercise(weekday: 3, exerciseID: "pulldown"), for: user())
        }
        #expect(store.plan == plan())
    }

    @Test func editWithoutAPlanThrowsNoPlan() {
        #expect(throws: WorkoutPlanError.noPlan) {
            try makeUseCase(PlanStoreStub()).execute(.removeExercise(weekday: 1, exerciseID: "press"), for: user())
        }
    }

    @Test func editReportsAStorageFailureWhenSaving() {
        let store = PlanStoreStub(plan: plan())
        store.failsOnSave = true
        #expect(throws: WorkoutPlanError.couldNotSavePlan) {
            try makeUseCase(store).execute(.setSets(weekday: 1, exerciseID: "press", sets: 4), for: user())
        }
    }

    @Test func deleteRemovesThePlanAndReportsFailures() throws {
        let store = PlanStoreStub(plan: plan())
        try makeUseCase(store).deletePlan()
        #expect(store.plan == nil)

        store.fails = true
        #expect(throws: WorkoutPlanError.couldNotDeletePlan) { try makeUseCase(store).deletePlan() }
    }

    private func makeUseCase(_ store: PlanStoreStub) -> EditWorkoutPlanUseCase {
        EditWorkoutPlanUseCase(plans: store, exercises: ExerciseCatalogueStub(exercises: catalogue))
    }
}

// MARK: - Fixtures

/// In-memory containers must outlive the contexts that use them.
@MainActor private var keepAlive: [ModelContainer] = []

private func exercise(_ id: String, category: String, minutes: Int, tags: [String] = ["low-impact"]) -> Exercise {
    Exercise(
        id: id, name: id, muscleGroup: category, primaryMuscle: "", secondaryMuscles: [], equipment: "machine",
        level: "beginner", loadType: "external", position: "seated", impact: "low", minimumReps: 10, maximumReps: 12,
        defaultRestSeconds: 60, shortDescription: "", instructions: [], coachingCues: [], commonMistakes: [],
        breathing: "", alternativeExerciseIDs: [], videoFile: nil, imageURL: nil, videoURL: nil, source: nil,
        categoryID: category, tagIDs: tags, estimatedMinutes: minutes)
}

private let catalogue = [
    exercise("press", category: "legs", minutes: 12),
    exercise("extension", category: "legs", minutes: 10),
    exercise("kickback", category: "glutes", minutes: 10),
    exercise("bridge", category: "glutes", minutes: 10, tags: ["low-impact", "floor-based"]),
    exercise("pulldown", category: "back", minutes: 12),
    exercise("curl", category: "arms", minutes: 10),
]

private func planned(_ id: String, sets: Int = 3) -> WorkoutExercise {
    WorkoutExercise(exercise: catalogue.first { $0.id == id }!, sets: sets)
}

/// Two workouts: Monday legs + glutes (press, kickback), Wednesday back (pulldown).
private func plan() -> WorkoutPlan {
    WorkoutPlan(goalID: "buildMuscle", workouts: [
        PlannedWorkout(weekday: 1, categoryIDs: ["legs", "glutes"], exercises: [planned("press"), planned("kickback")]),
        PlannedWorkout(weekday: 3, categoryIDs: ["back"], exercises: [planned("pulldown")]),
    ])
}

private func user(days: [Int] = [1, 3], minutes: Int = 60) -> UserPlanningProfile {
    UserPlanningProfile(level: .beginner, goalID: "buildMuscle", trainingDays: days, sessionMinutes: minutes)
}

private func ids(_ plan: WorkoutPlan, weekday: Int) -> [String] {
    plan.workouts.first { $0.weekday == weekday }?.exercises.map(\.id) ?? []
}

@MainActor
private struct ExerciseCatalogueStub: ExerciseRepository {
    let exercises: [Exercise]
    func load() throws -> [Exercise] { exercises }
    func exercise(id: String) -> Exercise? { exercises.first { $0.id == id } }
    func videoURL(for exercise: Exercise) -> URL? { nil }
}

/// Stands in for the plan store. `fails` breaks every call; `failsOnSave` breaks only saving.
@MainActor
final class PlanStoreStub: WorkoutPlanRepository {
    var plan: WorkoutPlan?
    var fails = false
    var failsOnSave = false

    init(plan: WorkoutPlan? = nil) { self.plan = plan }

    func loadPlan() throws -> WorkoutPlan? {
        if fails { throw CocoaError(.fileReadUnknown) }
        return plan
    }
    func savePlan(_ plan: WorkoutPlan) throws {
        if fails || failsOnSave { throw CocoaError(.fileWriteUnknown) }
        self.plan = plan
    }
    func deletePlan() throws {
        if fails { throw CocoaError(.fileWriteUnknown) }
        plan = nil
    }
}
