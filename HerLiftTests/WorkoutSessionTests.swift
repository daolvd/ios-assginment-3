import Foundation
import SwiftData
import Testing
@testable import HerLift

@MainActor
struct WorkoutSessionUseCaseTests {
    // Saturday 3 October 2026, so Saturday's workout is "today".
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()
    private var today: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 3, hour: 14))! }
    private var todayStart: Date { calendar.startOfDay(for: today) }

    @Test func startingCreatesAnInProgressLogForToday() throws {
        let store = SessionStoreStub()
        let log = try makeUseCase(store).start(workout(), on: today)

        #expect(log == WorkoutLog(date: todayStart, weekday: 6, status: .inProgress, sets: [], startedAt: today))
        #expect(store.logs[todayStart] == log)
    }

    @Test func startingAgainReturnsTheWorkoutAlreadyInProgress() throws {
        let useCase = makeUseCase(SessionStoreStub())
        let started = try useCase.start(workout(), on: today)
        let afterSet = try useCase.record(set("machine-chest-press", 1), in: started, of: workout())

        #expect(try useCase.start(workout(), on: today) == afterSet)
    }

    @Test func aWorkoutCanOnlyStartOnItsOwnDay() {
        let tuesday = calendar.date(from: DateComponents(year: 2026, month: 9, day: 29))!
        #expect(throws: WorkoutSessionError.notToday) { try makeUseCase(SessionStoreStub()).start(workout(), on: tuesday) }
    }

    @Test func aFinishedWorkoutCannotBeStartedAgain() throws {
        let useCase = makeUseCase(SessionStoreStub())
        let started = try useCase.start(workout(), on: today)
        let logged = try useCase.record(set("machine-chest-press", 1), in: started, of: workout())
        _ = try useCase.finish(logged)

        #expect(throws: WorkoutSessionError.alreadyCompleted) { try useCase.start(workout(), on: today) }
    }

    @Test func recordingAddsTheSetAndSavesIt() throws {
        let store = SessionStoreStub()
        let useCase = makeUseCase(store)
        let started = try useCase.start(workout(), on: today)

        let updated = try useCase.record(set("machine-chest-press", 1, kg: 20, reps: 12, .hard), in: started, of: workout())

        #expect(updated.sets == [LoggedSet(exerciseID: "machine-chest-press", setNumber: 1, weightKg: 20, repetitions: 12, effort: .hard)])
        #expect(store.logs[todayStart] == updated)
    }

    @Test func repetitionsMustBeBetweenOneAndOneHundred() throws {
        let useCase = makeUseCase(SessionStoreStub())
        let started = try useCase.start(workout(), on: today)

        for reps in [0, 101, -3] {
            #expect(throws: WorkoutSessionError.invalidRepetitionCount) {
                try useCase.record(set("machine-chest-press", 1, reps: reps), in: started, of: workout())
            }
        }
        for reps in [1, 100] {
            #expect(throws: Never.self) { try useCase.record(set("machine-chest-press", 1, reps: reps), in: started, of: workout()) }
        }
    }

    @Test func weightsFollowTheRulesOfTheExercise() throws {
        let useCase = makeUseCase(SessionStoreStub())
        let started = try useCase.start(workout(), on: today)

        for kg in [0, -5, 300.5, .nan] {
            #expect(throws: WorkoutSessionError.invalidWeight) {
                try useCase.record(set("machine-chest-press", 1, kg: kg), in: started, of: workout())
            }
        }
        #expect(throws: Never.self) { try useCase.record(set("machine-chest-press", 1, kg: 300), in: started, of: workout()) }
        // Reverse crunch is a bodyweight exercise: 0 kg only.
        #expect(throws: Never.self) { try useCase.record(set("reverse-crunch", 1, kg: 0), in: started, of: workout()) }
        #expect(throws: WorkoutSessionError.invalidWeight) {
            try useCase.record(set("reverse-crunch", 1, kg: 5), in: started, of: workout())
        }
    }

    @Test func aSetCannotBeLoggedTwiceOrBeyondThePlannedSets() throws {
        let useCase = makeUseCase(SessionStoreStub())
        let started = try useCase.start(workout(), on: today)
        let logged = try useCase.record(set("machine-chest-press", 1), in: started, of: workout())

        #expect(throws: WorkoutSessionError.duplicateSet) {
            try useCase.record(set("machine-chest-press", 1), in: logged, of: workout())
        }
        #expect(throws: WorkoutSessionError.allSetsCompleted) { // three sets are planned
            try useCase.record(set("machine-chest-press", 4), in: logged, of: workout())
        }
    }

    @Test func onlyExercisesOfTheWorkoutCanBeLoggedWhileItIsInProgress() throws {
        let useCase = makeUseCase(SessionStoreStub())
        let started = try useCase.start(workout(), on: today)

        #expect(throws: WorkoutSessionError.exerciseNotInWorkout) {
            try useCase.record(set("leg-press", 1), in: started, of: workout())
        }
        var finished = started
        finished.status = .completed
        #expect(throws: WorkoutSessionError.workoutNotActive) {
            try useCase.record(set("machine-chest-press", 1), in: finished, of: workout())
        }
    }

    @Test func storageFailuresAreReported() throws {
        let store = SessionStoreStub()
        let useCase = makeUseCase(store)
        store.failsOnSave = true
        #expect(throws: WorkoutSessionError.couldNotStartWorkout) { try useCase.start(workout(), on: today) }

        store.failsOnSave = false
        let started = try useCase.start(workout(), on: today)
        store.failsOnSave = true
        #expect(throws: WorkoutSessionError.couldNotSaveSet) {
            try useCase.record(set("machine-chest-press", 1), in: started, of: workout())
        }
        #expect(throws: WorkoutSessionError.nothingLogged) { try useCase.finish(started) }

        store.fails = true
        #expect(throws: WorkoutSessionError.couldNotLoadWorkouts) { try useCase.currentLog(on: today) }
    }

    @Test func finishingNeedsASetAndMarksTheDayCompleted() throws {
        let store = SessionStoreStub()
        let useCase = makeUseCase(store)
        let started = try useCase.start(workout(), on: today)
        #expect(throws: WorkoutSessionError.nothingLogged) { try useCase.finish(started) }
        #expect(try useCase.completedDays().isEmpty)

        let logged = try useCase.record(set("machine-chest-press", 1), in: started, of: workout())
        let finished = try useCase.finish(logged)

        #expect(finished.status == .completed)
        #expect(store.logs[todayStart] == finished)
        #expect(try useCase.completedDays() == [todayStart])
        #expect(throws: WorkoutSessionError.workoutNotActive) { try useCase.finish(finished) }
    }

    @Test func theNextStepGoesExerciseByExerciseThroughEverySet() throws {
        let plan = workout() // chest press 3 sets, reverse crunch 2 sets
        var log = WorkoutLog(date: todayStart, weekday: 6, status: .inProgress, sets: [])
        var steps: [WorkoutStep] = []
        while let step = plan.nextStep(after: log) {
            steps.append(step)
            log.sets.append(set(plan.exercises[step.exerciseIndex].id, step.setNumber))
        }

        #expect(steps == [
            WorkoutStep(exerciseIndex: 0, setNumber: 1), WorkoutStep(exerciseIndex: 0, setNumber: 2),
            WorkoutStep(exerciseIndex: 0, setNumber: 3), WorkoutStep(exerciseIndex: 1, setNumber: 1),
            WorkoutStep(exerciseIndex: 1, setNumber: 2),
        ])
    }

    private func makeUseCase(_ store: SessionStoreStub) -> WorkoutSessionUseCase {
        WorkoutSessionUseCase(sessions: store, calendar: calendar)
    }

    private func set(
        _ id: String, _ number: Int, kg: Double = 20, reps: Int = 10, _ effort: PerceivedEffort = .good
    ) -> LoggedSet {
        LoggedSet(exerciseID: id, setNumber: number, weightKg: kg, repetitions: reps, effort: effort)
    }
}

/// Saturday's workout: machine chest press (3 sets) and reverse crunch (2 sets, bodyweight). `target` is the
/// chest press's target weight.
@MainActor
func workout(target: Double? = nil) -> PlannedWorkout {
    let catalogue = try! JSONExerciseRepository().exercises
    func planned(_ id: String, sets: Int, kg: Double? = nil) -> WorkoutExercise {
        WorkoutExercise(exercise: catalogue.first { $0.id == id }!, sets: sets, targetWeightKg: kg)
    }
    return PlannedWorkout(
        weekday: 6, categoryIDs: ["chest", "core"],
        exercises: [planned("machine-chest-press", sets: 3, kg: target), planned("reverse-crunch", sets: 2)])
}

@MainActor
final class SessionStoreStub: WorkoutSessionRepository {
    var logs: [Date: WorkoutLog] = [:]
    var fails = false
    var failsOnSave = false

    func log(on day: Date) throws -> WorkoutLog? {
        if fails { throw CocoaError(.fileReadUnknown) }
        return logs[day]
    }
    func save(_ log: WorkoutLog) throws {
        if fails || failsOnSave { throw CocoaError(.fileWriteUnknown) }
        logs[log.date] = log
    }
    func completedDays() throws -> Set<Date> {
        if fails { throw CocoaError(.fileReadUnknown) }
        return Set(logs.values.filter { $0.status == .completed }.map(\.date))
    }
}

@MainActor
struct SwiftDataWorkoutSessionRepositoryTests {
    @Test func aLogComesBackWithItsSetsInOrder() throws {
        let repository = try makeRepository()
        let log = WorkoutLog(date: day(3), weekday: 6, status: .inProgress, sets: [
            LoggedSet(exerciseID: "reverse-crunch", setNumber: 1, weightKg: 0, repetitions: 15, effort: .easy),
            LoggedSet(exerciseID: "machine-chest-press", setNumber: 1, weightKg: 22.5, repetitions: 10, effort: .tooHard),
        ])

        try repository.save(log)

        #expect(try repository.log(on: day(3)) == log)
        #expect(try repository.log(on: day(4)) == nil)
    }

    @Test func savingTheSameDayReplacesItsLog() throws {
        let repository = try makeRepository()
        var log = WorkoutLog(date: day(3), weekday: 6, status: .inProgress, sets: [])
        try repository.save(log)
        log.sets.append(LoggedSet(exerciseID: "reverse-crunch", setNumber: 1, weightKg: 0, repetitions: 15, effort: .good))
        log.status = .completed

        try repository.save(log)

        #expect(try repository.log(on: day(3)) == log)
        #expect(try repository.completedDays() == [day(3)])
    }

    @Test func onlyFinishedWorkoutsCountAsCompletedDays() throws {
        let repository = try makeRepository()
        try repository.save(WorkoutLog(date: day(1), weekday: 4, status: .completed, sets: []))
        try repository.save(WorkoutLog(date: day(3), weekday: 6, status: .inProgress, sets: []))

        #expect(try repository.completedDays() == [day(1)])
    }

    private func day(_ number: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar.date(from: DateComponents(year: 2026, month: 10, day: number))!
    }

    private func makeRepository() throws -> SwiftDataWorkoutSessionRepository {
        let schema = Schema([WorkoutSession.self, ExerciseSet.self])
        let container = try ModelContainer(
            for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        sessionContainers.append(container)
        return SwiftDataWorkoutSessionRepository(modelContext: ModelContext(container))
    }
}

/// In-memory containers must outlive the contexts that use them.
@MainActor private var sessionContainers: [ModelContainer] = []

@MainActor
struct WorkoutSessionViewModelTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()
    private var saturday: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 3, hour: 14))! }

    @Test func theWeightAndRepsAreShownNotTypedWhenThePlanKnowsTheWeight() {
        let viewModel = makeViewModel(SessionStoreStub(), workout: workout(target: 20))
        viewModel.start()

        #expect(viewModel.weightText == "20")
        #expect(viewModel.repsText == "12")
        #expect(!viewModel.weightIsEditable)
    }

    @Test func theWeightCanBeTypedOnlyWhileNoneIsKnown() {
        let viewModel = makeViewModel(SessionStoreStub())
        viewModel.start()
        #expect(viewModel.weightIsEditable)

        viewModel.weightText = "15"
        viewModel.completeSet()

        #expect(!viewModel.weightIsEditable)
        #expect(viewModel.weightText == "15")
    }

    @Test func aBodyweightExerciseHasNoWeightBoxToType() {
        let viewModel = makeViewModel(SessionStoreStub())
        viewModel.start()
        viewModel.weightText = "20"
        for _ in 1...3 { viewModel.completeSet() }

        #expect(viewModel.current?.exercise.loadType == "bodyweight")
        #expect(!viewModel.weightIsEditable)
    }

    @Test func startingPutsHerOnTheFirstSetWithFreshInputs() {
        let viewModel = makeViewModel(SessionStoreStub())
        #expect(viewModel.buttonTitle == "Start workout")

        #expect(viewModel.start())

        #expect(viewModel.progressLine == "Exercise 1 of 2 · Set 1 of 3")
        #expect(viewModel.targetLine == "Find your weight × 10–12")
        #expect(viewModel.weightText.isEmpty)
        #expect(viewModel.repsText == "12")
        #expect(viewModel.effort == .good)
        #expect(!viewModel.canCompleteSet) // no weight yet
    }

    @Test func completingASetMovesOnAndKeepsTheWeight() {
        let viewModel = makeViewModel(SessionStoreStub())
        viewModel.start()
        viewModel.weightText = "20"
        viewModel.repsText = "11"
        viewModel.effort = .hard

        #expect(viewModel.canCompleteSet)
        viewModel.completeSet()

        #expect(viewModel.log?.sets == [LoggedSet(exerciseID: "machine-chest-press", setNumber: 1, weightKg: 20, repetitions: 11, effort: .hard)])
        #expect(viewModel.progressLine == "Exercise 1 of 2 · Set 2 of 3")
        #expect(viewModel.targetLine == "Target 20 kg × 10–12")
        #expect(viewModel.weightText == "20")
        #expect(viewModel.repsText == "12")
        #expect(viewModel.effort == .good)
    }

    @Test func thingsThatCannotBeASetShowTheirMessageAndBlockCompleteSet() {
        let viewModel = makeViewModel(SessionStoreStub())
        viewModel.start()
        viewModel.weightText = "20"
        #expect(viewModel.repsMessage == nil)

        viewModel.repsText = "0"
        #expect(viewModel.repsMessage == .invalidRepetitionCount)
        #expect(!viewModel.canCompleteSet)

        viewModel.repsText = "10"
        viewModel.weightText = "abc"
        #expect(viewModel.weightMessage == .invalidWeight)
        #expect(!viewModel.canCompleteSet)

        viewModel.weightText = "22,5"
        #expect(viewModel.weightMessage == nil)
        #expect(viewModel.canCompleteSet)
    }

    @Test func aBodyweightExerciseAsksOnlyForReps() {
        let viewModel = makeViewModel(SessionStoreStub())
        viewModel.start()
        for _ in 1...3 { // the three chest press sets
            viewModel.weightText = "20"
            viewModel.completeSet()
        }

        #expect(viewModel.current?.id == "reverse-crunch")
        #expect(!viewModel.showsWeightField)
        #expect(viewModel.targetLine == "Bodyweight × 10–15")
        #expect(viewModel.canCompleteSet)
        viewModel.completeSet()
        #expect(viewModel.log?.sets.last == LoggedSet(exerciseID: "reverse-crunch", setNumber: 1, weightKg: 0, repetitions: 15, effort: .good))
    }

    @Test func afterTheLastSetTheWorkoutIsReadyToFinish() {
        let viewModel = makeViewModel(SessionStoreStub())
        viewModel.start()
        for _ in 1...3 { viewModel.weightText = "20"; viewModel.completeSet() }
        for _ in 1...2 { viewModel.completeSet() }

        #expect(viewModel.step == nil)
        #expect(viewModel.isReadyToFinish)
        #expect(viewModel.finish())
        #expect(viewModel.isFinished)
        #expect(viewModel.buttonTitle == "Workout done")
    }

    @Test func aWorkoutLeftHalfDoneIsResumedWhereItStopped() {
        let store = SessionStoreStub()
        let first = makeViewModel(store)
        first.start()
        first.weightText = "20"
        first.completeSet()

        let reopened = makeViewModel(store)
        reopened.load()

        #expect(reopened.buttonTitle == "Resume workout")
        #expect(reopened.progressLine == "Exercise 1 of 2 · Set 2 of 3")
        #expect(reopened.weightText == "20")
    }

    @Test func aSaveFailureLeavesTheSetUnlogged() {
        let store = SessionStoreStub()
        let viewModel = makeViewModel(store)
        viewModel.start()
        viewModel.weightText = "20"
        store.failsOnSave = true

        viewModel.completeSet()

        #expect(viewModel.error == .couldNotSaveSet)
        #expect(viewModel.log?.sets.isEmpty == true)
        #expect(viewModel.progressLine == "Exercise 1 of 2 · Set 1 of 3")
    }

    @Test func finishingNeedsAtLeastOneSetButCanComeEarly() {
        let viewModel = makeViewModel(SessionStoreStub())
        viewModel.start()
        #expect(!viewModel.finish())
        #expect(viewModel.error == .nothingLogged)

        viewModel.error = nil
        viewModel.weightText = "20"
        viewModel.completeSet()
        #expect(viewModel.finish())
        #expect(viewModel.isFinished)
    }

    @Test func theHomeScreenMarksFinishedWorkoutsDone() throws {
        let store = SessionStoreStub()
        let day = calendar.startOfDay(for: saturday)
        store.logs[day] = WorkoutLog(date: day, weekday: 6, status: .completed, sets: [])
        let plans = PlanStoreStub(plan: WorkoutPlan(
            goalID: "buildMuscle", workouts: [workout()], status: .active, startedOn: day))
        let myPlan = MyPlanViewModel(
            editPlan: EditWorkoutPlanUseCase(plans: plans, exercises: try JSONExerciseRepository()),
            workoutSessions: WorkoutSessionUseCase(sessions: store, calendar: calendar), goals: [], now: { saturday })

        myPlan.load()

        #expect(myPlan.completedDays == [day])
        #expect(myPlan.sessionViewModel(for: workout()) === myPlan.sessionViewModel(for: workout()))
    }

    private func makeViewModel(_ store: SessionStoreStub, workout planned: PlannedWorkout? = nil) -> WorkoutSessionViewModel {
        WorkoutSessionViewModel(
            workout: planned ?? workout(), useCase: WorkoutSessionUseCase(sessions: store, calendar: calendar),
            editPlan: EditWorkoutPlanUseCase(
                plans: PlanStoreStub(plan: WorkoutPlan(goalID: "buildMuscle", workouts: [workout()], status: .active)),
                exercises: try! JSONExerciseRepository()),
            now: { saturday })
    }
}
