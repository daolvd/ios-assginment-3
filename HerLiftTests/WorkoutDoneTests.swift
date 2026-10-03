import Foundation
import SwiftData
import Testing
@testable import HerLift

// MARK: - What a finished workout means

@MainActor
struct WorkoutFeedbackTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    // Machine chest press: 10–12 reps, 3 planned sets. Reverse crunch: bodyweight.
    @Test func startingWeightIsTheHeaviestSetThatReachedTheLowestRepsAndFeltEasyOrGood() {
        let summary = WorkoutFeedback.summary(of: workout(), log: log([
            set("machine-chest-press", 1, kg: 20, reps: 10, .good),
            set("machine-chest-press", 2, kg: 25, reps: 10, .easy),
            set("machine-chest-press", 3, kg: 30, reps: 8, .hard),
        ]))

        #expect(summary.startingWeights.map(\.weightKg) == [25])
        #expect(summary.startingWeights.first?.exerciseName == "Machine Chest Press")
        #expect(summary.proposals.isEmpty)
    }

    @Test func withoutAComfortableSetTheStartingWeightIsTheLightest() {
        let summary = WorkoutFeedback.summary(of: workout(), log: log([
            set("machine-chest-press", 1, kg: 30, reps: 8, .tooHard),
            set("machine-chest-press", 2, kg: 25, reps: 9, .hard),
        ]))
        #expect(summary.startingWeights.map(\.weightKg) == [25])
    }

    @Test func bodyweightExercisesNeverGetAWeight() {
        let summary = WorkoutFeedback.summary(of: workout(), log: log([set("reverse-crunch", 1, kg: 0, reps: 15, .easy)]))
        #expect(summary.startingWeights.isEmpty)
        #expect(summary.proposals.isEmpty)
    }

    @Test func everyPlannedSetEasyOrGoodAtTheTopProposesOneStepHeavier() {
        let summary = WorkoutFeedback.summary(of: workout(target: 20), log: log([
            set("machine-chest-press", 1, kg: 20, reps: 12, .good),
            set("machine-chest-press", 2, kg: 20, reps: 12, .easy),
            set("machine-chest-press", 3, kg: 20, reps: 12, .good),
        ]))

        #expect(summary.proposals == [WeightProposal(
            weekday: 6, exerciseID: "machine-chest-press", exerciseName: "Machine Chest Press",
            currentKg: 20, proposedKg: 22.5)])
        #expect(summary.proposals.first?.changeText == "20 → 22.5 kg")
        #expect(summary.startingWeights.isEmpty) // it already had a weight
    }

    @Test func aHeavierWeightNeedsEverySetDoneAtTheTopAndNotFeelingHard() {
        func proposals(_ sets: [LoggedSet]) -> [WeightProposal] {
            WorkoutFeedback.summary(of: workout(target: 20), log: log(sets)).proposals
        }
        let top = { (number: Int, reps: Int, effort: PerceivedEffort) in set("machine-chest-press", number, kg: 20, reps: reps, effort) }

        #expect(proposals([top(1, 12, .good), top(2, 12, .good)]).isEmpty) // a planned set is missing
        #expect(proposals([top(1, 12, .good), top(2, 11, .good), top(3, 12, .good)]).isEmpty) // 11 is below the top
        #expect(proposals([top(1, 12, .good), top(2, 12, .hard), top(3, 12, .good)]).isEmpty) // one felt hard
    }

    @Test func twoSetsThatWereTooHardOrShortOfRepsProposeOneStepLighter() {
        func proposed(_ sets: [LoggedSet], target: Double = 20) -> Double? {
            WorkoutFeedback.summary(of: workout(target: target), log: log(sets)).proposals.first?.proposedKg
        }
        let tooHard = { (n: Int) in set("machine-chest-press", n, kg: 20, reps: 11, .tooHard) }
        let short = { (n: Int) in set("machine-chest-press", n, kg: 20, reps: 9, .good) }

        #expect(proposed([tooHard(1), tooHard(2)]) == 17.5)
        #expect(proposed([short(1), short(2)]) == 17.5)
        #expect(proposed([tooHard(1), short(2)]) == 17.5)
        #expect(proposed([tooHard(1)]) == nil) // one is not enough
        #expect(proposed([tooHard(1), tooHard(2)], target: 2.5) == nil) // it would reach zero
    }

    @Test func theSummaryNamesTheWorkoutAndCountsTheSetsAndMinutes() {
        let start = calendar.date(from: DateComponents(year: 2026, month: 10, day: 3, hour: 14))!
        var finished = log([set("machine-chest-press", 1, kg: 20, reps: 10, .good), set("reverse-crunch", 1, kg: 0, reps: 12, .good)])
        finished.startedAt = start
        finished.completedAt = start.addingTimeInterval(43 * 60 + 20)

        let summary = WorkoutFeedback.summary(of: workout(), log: finished)

        #expect(summary.title == "Chest · Core")
        #expect(summary.setCount == 2)
        #expect(summary.minutes == 43)

        finished.completedAt = start.addingTimeInterval(5)
        #expect(WorkoutFeedback.summary(of: workout(), log: finished).minutes == 1)
        finished.completedAt = nil
        #expect(WorkoutFeedback.summary(of: workout(), log: finished).minutes == nil)
    }

    private func workout(target: Double? = nil) -> PlannedWorkout {
        let base = HerLiftTests.workout()
        var exercises = base.exercises
        exercises[0].targetWeightKg = target
        return PlannedWorkout(weekday: base.weekday, categoryIDs: base.categoryIDs, exercises: exercises)
    }

    private func log(_ sets: [LoggedSet]) -> WorkoutLog {
        WorkoutLog(date: calendar.startOfDay(for: Date()), weekday: 6, status: .completed, sets: sets)
    }

    private func set(_ id: String, _ number: Int, kg: Double, reps: Int, _ effort: PerceivedEffort) -> LoggedSet {
        LoggedSet(exerciseID: id, setNumber: number, weightKg: kg, repetitions: reps, effort: effort)
    }
}

// MARK: - Target weights in the plan

@MainActor
struct TargetWeightTests {
    @Test func targetWeightsAreSetOnTheRightExercise() throws {
        let store = PlanStoreStub(plan: plan())
        let useCase = EditWorkoutPlanUseCase(plans: store, exercises: try JSONExerciseRepository())

        let updated = try useCase.setTargetWeights([TargetWeightChange(weekday: 6, exerciseID: "machine-chest-press", weightKg: 27.5)])

        #expect(updated.workouts[0].exercises.map(\.targetWeightKg) == [27.5, nil])
        #expect(store.plan == updated)
    }

    @Test func badChangesAreRejectedAndNothingIsSaved() throws {
        let store = PlanStoreStub(plan: plan())
        let useCase = EditWorkoutPlanUseCase(plans: store, exercises: try JSONExerciseRepository())
        func change(_ weekday: Int = 6, _ id: String = "machine-chest-press", _ kg: Double = 20) -> [TargetWeightChange] {
            [TargetWeightChange(weekday: weekday, exerciseID: id, weightKg: kg)]
        }

        #expect(throws: WorkoutPlanError.workoutNotFound) { try useCase.setTargetWeights(change(2)) }
        #expect(throws: WorkoutPlanError.exerciseNotFound) { try useCase.setTargetWeights(change(6, "leg-press")) }
        for kg in [0, -1, 300.5, Double.nan] {
            #expect(throws: WorkoutPlanError.invalidWeight) { try useCase.setTargetWeights(change(6, "machine-chest-press", kg)) }
        }
        #expect(throws: WorkoutPlanError.invalidWeight) { try useCase.setTargetWeights(change(6, "reverse-crunch", 5)) }
        #expect(store.plan == plan())

        store.plan = nil
        #expect(throws: WorkoutPlanError.noPlan) { try useCase.setTargetWeights(change()) }
        store.plan = plan()
        store.failsOnSave = true
        #expect(throws: WorkoutPlanError.couldNotSavePlan) { try useCase.setTargetWeights(change()) }
    }

    @Test func targetWeightsSurviveTheSwiftDataStore() throws {
        let schema = Schema([TrainingPlan.self, WorkoutDay.self, PlannedExercise.self])
        let container = try ModelContainer(
            for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let repository = SwiftDataWorkoutPlanRepository(modelContext: ModelContext(container), exercises: try JSONExerciseRepository())
        var withWeights = plan()
        var exercises = withWeights.workouts[0].exercises
        exercises[0].targetWeightKg = 32.5
        withWeights = withWeights.replacingWorkouts([PlannedWorkout(weekday: 6, categoryIDs: ["chest", "core"], exercises: exercises)])

        try repository.savePlan(withWeights)

        #expect(try repository.loadPlan() == withWeights)
        #expect(try repository.loadPlan()?.workouts[0].exercises.map(\.targetWeightKg) == [32.5, nil])
    }

    @Test func aWorkoutLogKeepsItsStartAndFinishTimes() throws {
        let schema = Schema([WorkoutSession.self, ExerciseSet.self])
        let container = try ModelContainer(
            for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let repository = SwiftDataWorkoutSessionRepository(modelContext: ModelContext(container))
        let day = Date(timeIntervalSince1970: 1_790_000_000)
        let log = WorkoutLog(
            date: day, weekday: 6, status: .completed, sets: [], startedAt: day.addingTimeInterval(60),
            completedAt: day.addingTimeInterval(2_700))

        try repository.save(log)

        #expect(try repository.log(on: day) == log)
    }

    private func plan() -> WorkoutPlan {
        WorkoutPlan(goalID: "buildMuscle", workouts: [workout()], status: .active)
    }
}

// MARK: - Finishing a workout in the view model

@MainActor
struct WorkoutDoneViewModelTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()
    private var saturday: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 3, hour: 14))! }

    @Test func aFirstWorkoutSavesItsStartingWeightsToThePlan() {
        let fixture = makeFixture()
        fixture.viewModel.start()
        fixture.viewModel.weightText = "25"
        fixture.viewModel.repsText = "11"
        fixture.viewModel.completeSet()

        #expect(fixture.viewModel.finish())

        #expect(fixture.viewModel.summary?.startingWeights.map(\.weightKg) == [25])
        #expect(fixture.planStore.plan?.workouts[0].exercises.map(\.targetWeightKg) == [25, nil])
        #expect(fixture.viewModel.error == nil)
        #expect(fixture.viewModel.summary?.proposals.isEmpty == true)
    }

    @Test func aFirstTimeExerciseAsksHerToPickAWeightUntilOneIsKnown() {
        let fresh = makeFixture()
        fresh.viewModel.start()
        #expect(fresh.viewModel.weightHint == "Pick a weight you could lift about 15 times.")

        fresh.viewModel.weightText = "20"
        fresh.viewModel.completeSet()
        #expect(fresh.viewModel.weightHint == nil) // the first set showed a weight

        let known = makeFixture(target: 20)
        known.viewModel.start()
        #expect(known.viewModel.weightHint == nil)
    }

    @Test func bodyweightExercisesNeverAskForAWeight() {
        let fixture = makeFixture()
        fixture.viewModel.start()
        for _ in 1...3 { // the chest press sets
            fixture.viewModel.endRest()
            fixture.viewModel.weightText = "20"
            fixture.viewModel.completeSet()
        }

        #expect(fixture.viewModel.current?.id == "reverse-crunch")
        #expect(fixture.viewModel.weightHint == nil)
    }

    @Test func theFirstSetStartsFromTheTargetWeightOfThePlan() {
        let fixture = makeFixture(target: 20)
        fixture.viewModel.start()

        #expect(fixture.viewModel.weightText == "20")
        #expect(fixture.viewModel.targetLine == "Target 20 kg × 10–12")
    }

    @Test func proposalsWaitUntilSheAppliesOrKeepsThem() {
        let fixture = makeFixture(target: 20)
        finishWithEveryChestPressSetEasyAtTheTop(fixture.viewModel)
        let proposal = try! #require(fixture.viewModel.summary?.proposals.first)
        #expect(proposal.proposedKg == 22.5)
        #expect(fixture.viewModel.pendingProposals == [proposal])
        #expect(fixture.planStore.plan?.workouts[0].exercises[0].targetWeightKg == 20) // nothing changed yet

        fixture.viewModel.apply(proposal)

        #expect(fixture.viewModel.decisions[proposal.id] == .applied)
        #expect(fixture.planStore.plan?.workouts[0].exercises[0].targetWeightKg == 22.5)
        #expect(fixture.viewModel.pendingProposals.isEmpty)
    }

    @Test func keepingAProposalLeavesThePlanAsItIs() {
        let fixture = makeFixture(target: 20)
        finishWithEveryChestPressSetEasyAtTheTop(fixture.viewModel)
        let proposal = try! #require(fixture.viewModel.summary?.proposals.first)

        fixture.viewModel.keep(proposal)

        #expect(fixture.viewModel.decisions[proposal.id] == .kept)
        #expect(fixture.planStore.plan?.workouts[0].exercises[0].targetWeightKg == 20)
    }

    @Test func applyAllAndKeepAllDecideTheWholeList() {
        let applied = makeFixture(target: 20)
        finishWithEveryChestPressSetEasyAtTheTop(applied.viewModel)
        applied.viewModel.applyAll()
        #expect(applied.planStore.plan?.workouts[0].exercises[0].targetWeightKg == 22.5)
        #expect(applied.viewModel.pendingProposals.isEmpty)

        let kept = makeFixture(target: 20)
        finishWithEveryChestPressSetEasyAtTheTop(kept.viewModel)
        kept.viewModel.keepAll()
        #expect(kept.planStore.plan?.workouts[0].exercises[0].targetWeightKg == 20)
        #expect(kept.viewModel.pendingProposals.isEmpty)
    }

    @Test func aProposalIsNotMarkedAppliedWhenThePlanCannotBeSaved() {
        let fixture = makeFixture(target: 20)
        finishWithEveryChestPressSetEasyAtTheTop(fixture.viewModel)
        let proposal = try! #require(fixture.viewModel.summary?.proposals.first)
        fixture.planStore.failsOnSave = true

        fixture.viewModel.apply(proposal)

        #expect(fixture.viewModel.error == .couldNotUpdatePlan)
        #expect(fixture.viewModel.decisions[proposal.id] == nil)
    }

    // MARK: Fixtures

    private struct Fixture {
        let viewModel: WorkoutSessionViewModel
        let planStore: PlanStoreStub
    }

    private func makeFixture(target: Double? = nil) -> Fixture {
        let base = workout()
        var exercises = base.exercises
        exercises[0].targetWeightKg = target
        let planned = PlannedWorkout(weekday: base.weekday, categoryIDs: base.categoryIDs, exercises: exercises)
        let planStore = PlanStoreStub(plan: WorkoutPlan(goalID: "buildMuscle", workouts: [planned], status: .active))
        let viewModel = WorkoutSessionViewModel(
            workout: planned, useCase: WorkoutSessionUseCase(sessions: SessionStoreStub(), calendar: calendar),
            editPlan: EditWorkoutPlanUseCase(plans: planStore, exercises: try! JSONExerciseRepository()),
            now: { saturday })
        return Fixture(viewModel: viewModel, planStore: planStore)
    }

    private func finishWithEveryChestPressSetEasyAtTheTop(_ viewModel: WorkoutSessionViewModel) {
        viewModel.start()
        for _ in 1...3 {
            viewModel.endRest()
            viewModel.repsText = "12"
            viewModel.effort = .good
            viewModel.completeSet()
        }
        viewModel.finish()
    }
}
