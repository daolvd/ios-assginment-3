import Foundation
import Testing
@testable import HerLift

/// Saturday 3 October 2026, 14:00 in the device's time zone, and the days around it.
nonisolated private enum Clock {
    static let calendar = Calendar.current
    static var saturday: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 3, hour: 14))! }
    static var saturdayStart: Date { calendar.startOfDay(for: saturday) }
    static func day(_ offset: Int, hour: Int = 0, minute: Int = 0) -> Date {
        let day = calendar.date(byAdding: .day, value: offset, to: saturdayStart)!
        return calendar.date(byAdding: .minute, value: hour * 60 + minute, to: day)!
    }
}

// MARK: - What the app tells the widget

@MainActor
struct CoachSnapshotBuilderTests {
    /// Saturday's Chest · Core workout, and Legs on Wednesday.
    private func plan(status: PlanStatus = .active, target: Double? = nil) -> WorkoutPlan {
        var saturday = workout()
        if let target {
            saturday = PlannedWorkout(
                weekday: 6, categoryIDs: saturday.categoryIDs,
                exercises: saturday.exercises.map { var e = $0; e.targetWeightKg = target; return e })
        }
        let wednesday = PlannedWorkout(weekday: 3, categoryIDs: ["legs"], exercises: saturday.exercises)
        return WorkoutPlan(
            goalID: "buildMuscle", workouts: [wednesday, saturday], status: status,
            startedOn: Clock.calendar.date(byAdding: .day, value: -7, to: Clock.saturdayStart))
    }

    private func make(
        _ plan: WorkoutPlan?, log: WorkoutLog? = nil, done: Set<Date> = [], now: Date = Clock.saturday
    ) -> CoachSnapshot {
        CoachSnapshotBuilder.make(plan: plan, log: log, completedDays: done, now: now, trainingMinute: 18 * 60)
    }

    private func log(_ sets: [LoggedSet], status: WorkoutStatus = .inProgress) -> WorkoutLog {
        WorkoutLog(
            date: Clock.saturdayStart, weekday: 6, status: status, sets: sets,
            startedAt: Clock.day(0, hour: 18), completedAt: status == .completed ? Clock.day(0, hour: 18, minute: 43) : nil)
    }

    private func set(_ id: String, _ number: Int, kg: Double = 20) -> LoggedSet {
        LoggedSet(exerciseID: id, setNumber: number, weightKg: kg, repetitions: 10, effort: .good)
    }

    private var allSets: [LoggedSet] {
        [set("machine-chest-press", 1), set("machine-chest-press", 2), set("machine-chest-press", 3),
         set("reverse-crunch", 1, kg: 0), set("reverse-crunch", 2, kg: 0)]
    }

    @Test func withoutAnAcceptedPlanThereIsNothingToShow() {
        #expect(make(nil).phase == .noPlan)
        #expect(make(plan(status: .draft)).phase == .noPlan)
    }

    @Test func aWorkoutNotStartedIsReadyWithEverySetSoItCanBeStartedOnTheWidget() {
        let snapshot = make(plan(target: 20))

        #expect(snapshot.phase == .ready)
        #expect(snapshot.day == Clock.saturdayStart)
        #expect(snapshot.today == CoachSnapshot.Workout(title: "Chest · Core", minutes: workout().estimatedMinutes, startsAt: Clock.day(0, hour: 18)))
        #expect(snapshot.steps.count == 5)
        #expect(snapshot.steps.first?.exerciseNumber == 1)
        #expect(snapshot.steps.first?.exerciseCount == 2)
        #expect(snapshot.steps.first?.weightKg == 20)
        #expect(snapshot.steps.last?.isBodyweight == true)
        #expect(snapshot.steps.last?.weightKg == 0)
    }

    @Test func theNextTrainingDayCarriesItsTimeAndTitle() {
        let snapshot = make(plan())

        #expect(snapshot.next == CoachSnapshot.Workout(title: "Legs", minutes: workout().estimatedMinutes, startsAt: Clock.day(4, hour: 18)))
    }

    @Test func aRestDayHasNoWorkoutOfItsOwn() {
        let snapshot = make(plan(), now: Clock.day(1, hour: 9))

        #expect(snapshot.phase == .restDay)
        #expect(snapshot.today == nil)
        #expect(snapshot.next?.title == "Legs")
        #expect(snapshot.steps.isEmpty)
    }

    @Test func theWeekRunsMondayToSundayWithTrainingAndDoneDays() {
        let wednesday = Clock.day(-3)
        let snapshot = make(plan(), done: [wednesday])

        #expect(snapshot.week.count == 7)
        #expect(snapshot.week.map(\.isTraining) == [false, false, true, false, false, true, false])
        #expect(snapshot.week.map(\.isDone) == [false, false, true, false, false, false, false])
    }

    @Test func aStartedWorkoutListsOnlyTheSetsStillToDo() {
        let snapshot = make(plan(target: 20), log: log([set("machine-chest-press", 1, kg: 25)]))

        #expect(snapshot.phase == .logging)
        #expect(snapshot.steps.count == 4)
        #expect(snapshot.steps.first?.setNumber == 2)
        #expect(snapshot.steps.first?.weightKg == 25)
        #expect(snapshot.loggedSetCount == 1)
        #expect(snapshot.startedAt == Clock.day(0, hour: 18))
    }

    @Test func theAppsRestIsSharedOnlyWhileTheWorkoutIsUnderWay() {
        let restEnds = Clock.day(0, hour: 18, minute: 2)
        let logging = CoachSnapshotBuilder.make(
            plan: plan(), log: log([set("machine-chest-press", 1)]), completedDays: [], now: Clock.saturday,
            trainingMinute: 18 * 60, restEndsAt: restEnds)
        let ready = CoachSnapshotBuilder.make(
            plan: plan(), log: nil, completedDays: [], now: Clock.saturday, trainingMinute: 18 * 60, restEndsAt: restEnds)

        #expect(logging.restEndsAt == restEnds)
        #expect(ready.restEndsAt == nil)
    }

    @Test func aWorkoutWithEverySetLoggedWaitsToBeFinished() {
        let snapshot = make(plan(), log: log(allSets))

        #expect(snapshot.phase == .allSetsDone)
        #expect(snapshot.loggedSetCount == 5)
    }

    @Test func aFinishedWorkoutIsDoneWithItsSummaryAndMarkedInTheWeek() {
        let snapshot = make(plan(), log: log(allSets, status: .completed))

        #expect(snapshot.phase == .done)
        #expect(snapshot.summary == CoachSnapshot.Summary(setCount: 5, minutes: 43))
        #expect(snapshot.week[5].isDone)
    }
}

// MARK: - The widget's screens and buttons

@MainActor
struct WidgetCoachingTests {
    private let now = Clock.day(0, hour: 18, minute: 5)
    private let today = CoachSnapshot.Workout(title: "Chest · Core", minutes: 40, startsAt: Clock.day(0, hour: 18))
    private let next = CoachSnapshot.Workout(title: "Legs", minutes: 45, startsAt: Clock.day(4, hour: 18))

    private func step(_ id: String, set: Int, kg: Double? = 20, bodyweight: Bool = false) -> CoachSnapshot.Step {
        CoachSnapshot.Step(
            exerciseID: id, exerciseName: id, exerciseNumber: 1, exerciseCount: 1, setNumber: set, setCount: 3,
            weightKg: kg, isBodyweight: bodyweight, minimumReps: 10, maximumReps: 12, restSeconds: 90)
    }

    private func snapshot(
        _ phase: CoachSnapshot.Phase, _ steps: [CoachSnapshot.Step] = [], logged: Int = 0, appRestEnds: Date? = nil
    ) -> CoachSnapshot {
        CoachSnapshot(
            phase: phase, day: Clock.saturdayStart, today: phase == .restDay ? nil : today, next: next, week: [],
            steps: steps, loggedSetCount: logged, startedAt: nil, restEndsAt: appRestEnds, summary: nil, updatedAt: now)
    }

    private func inbox(reps: Int = 0, started: Bool = false) -> WidgetInbox {
        WidgetInbox(day: Clock.saturdayStart, startedAt: started ? now : nil, reps: reps)
    }

    private func screen(_ snapshot: CoachSnapshot?, _ inbox: WidgetInbox, at time: Date? = nil) -> WidgetCoaching.Screen {
        WidgetCoaching.screen(snapshot, inbox, now: time ?? now)
    }

    @Test func aWorkoutNotStartedShowsTheScheduleWithStart() {
        #expect(screen(snapshot(.ready, [step("a", set: 1)]), inbox()) == .schedule(today: today, next: next, canStart: true))
    }

    @Test func aRestDayShowsTheNextWorkoutWithoutStart() {
        #expect(screen(snapshot(.restDay), inbox()) == .schedule(today: nil, next: next, canStart: false))
    }

    @Test func withoutAPlanOrSnapshotThereIsNothingToShow() {
        #expect(screen(nil, inbox()) == .noPlan)
        #expect(screen(snapshot(.noPlan), inbox()) == .noPlan)
    }

    @Test func startingOnTheWidgetGoesStraightToTheFirstSet() {
        let ready = snapshot(.ready, [step("a", set: 1), step("a", set: 2)])

        let started = WidgetCoaching.start(ready, inbox(reps: 4), now: now)

        #expect(started.startedAt == now)
        #expect(started.reps == 0)
        #expect(screen(ready, started) == .log(step("a", set: 1), weightKg: 20, reps: 0))
    }

    @Test func startDoesNothingOnceTheWorkoutIsUnderWay() {
        let logging = snapshot(.logging, [step("a", set: 1)])

        #expect(WidgetCoaching.start(logging, inbox(), now: now).startedAt == nil)
    }

    @Test func repsCountUpStopAtOneHundredAndResetToZero() {
        let logging = snapshot(.logging, [step("a", set: 1)])
        var counted = inbox()
        for _ in 1...3 { counted = WidgetCoaching.addRep(logging, counted) }
        #expect(counted.reps == 3)
        #expect(WidgetCoaching.reset(logging, counted).reps == 0)
        #expect(WidgetCoaching.addRep(logging, inbox(reps: 100)).reps == 100)
    }

    @Test func completeSetNeedsAtLeastOneRep() {
        let logging = snapshot(.logging, [step("a", set: 1)])

        #expect(WidgetCoaching.complete(logging, inbox(), now: now).sets.isEmpty)
    }

    @Test func completeSetLogsTheCountedRepsAndRunsTheRest() {
        let logging = snapshot(.logging, [step("a", set: 1), step("a", set: 2)])

        let after = WidgetCoaching.complete(logging, inbox(reps: 11), now: now)

        #expect(after.sets == [WidgetInbox.LoggedSet(
            exerciseID: "a", setNumber: 1, weightKg: 20, repetitions: 11, effort: "good", loggedAt: now)])
        #expect(after.reps == 0)
        #expect(after.restEndsAt == now.addingTimeInterval(90))
        #expect(screen(logging, after) == .rest(until: now.addingTimeInterval(90), next: step("a", set: 2)))
        #expect(screen(logging, after, at: now.addingTimeInterval(91)) == .log(step("a", set: 2), weightKg: 20, reps: 0))
    }

    @Test func skipRestGoesBackToTheNextSet() {
        let logging = snapshot(.logging, [step("a", set: 1), step("a", set: 2)])
        let resting = WidgetCoaching.complete(logging, inbox(reps: 10), now: now)

        #expect(screen(logging, WidgetCoaching.skipRest(logging, resting, now: now)) == .log(step("a", set: 2), weightKg: 20, reps: 0))
    }

    @Test func aRestRunningInTheAppShowsOnTheWidget() {
        let logging = snapshot(.logging, [step("a", set: 2)], logged: 1, appRestEnds: now.addingTimeInterval(60))

        #expect(screen(logging, inbox()) == .rest(until: now.addingTimeInterval(60), next: step("a", set: 2)))
        #expect(screen(logging, inbox(), at: now.addingTimeInterval(61)) == .log(step("a", set: 2), weightKg: 20, reps: 0))
    }

    @Test func skippingOnTheWidgetEndsTheAppsRestThere() {
        let logging = snapshot(.logging, [step("a", set: 2)], logged: 1, appRestEnds: now.addingTimeInterval(60))

        let skipped = WidgetCoaching.skipRest(logging, inbox(), now: now)

        #expect(skipped.restEndsAt == now)
        #expect(screen(logging, skipped) == .log(step("a", set: 2), weightKg: 20, reps: 0))
    }

    @Test func afterTheLastSetEverySetIsDoneWithNoRest() {
        let logging = snapshot(.logging, [step("a", set: 3)], logged: 2)

        let after = WidgetCoaching.complete(logging, inbox(reps: 10), now: now)

        #expect(after.restEndsAt == nil)
        #expect(screen(logging, after) == .allSetsDone(title: "Chest · Core", setCount: 3, startedAt: nil))
    }

    @Test func withoutAKnownWeightTheSetCannotBeLoggedOnTheWidget() {
        let logging = snapshot(.logging, [step("a", set: 1, kg: nil)])

        #expect(screen(logging, inbox(reps: 10)) == .log(step("a", set: 1, kg: nil), weightKg: nil, reps: 10))
        #expect(WidgetCoaching.complete(logging, inbox(reps: 10), now: now).sets.isEmpty)
    }

    @Test func bodyweightSetsNeedNoWeight() {
        let logging = snapshot(.logging, [step("a", set: 1, kg: nil, bodyweight: true)])

        #expect(WidgetCoaching.complete(logging, inbox(reps: 10), now: now).sets.first?.weightKg == 0)
    }

    @Test func aWeightLoggedOnTheWidgetCarriesToTheNextSetOfTheSameExercise() {
        let logging = snapshot(.logging, [step("a", set: 1, kg: nil), step("a", set: 2, kg: nil)])
        let earlier = WidgetInbox(
            day: Clock.saturdayStart,
            sets: [WidgetInbox.LoggedSet(exerciseID: "a", setNumber: 1, weightKg: 17.5, repetitions: 10, effort: "good", loggedAt: now)])

        #expect(screen(logging, earlier) == .log(step("a", set: 2, kg: nil), weightKg: 17.5, reps: 0))
    }

    @Test func anInboxFromAnotherDayIsIgnored() {
        let logging = snapshot(.logging, [step("a", set: 1), step("a", set: 2)])
        let yesterday = WidgetInbox(
            day: Clock.day(-1), reps: 9,
            sets: [WidgetInbox.LoggedSet(exerciseID: "a", setNumber: 1, weightKg: 20, repetitions: 10, effort: "good", loggedAt: Clock.day(-1))])

        #expect(screen(logging, yesterday) == .log(step("a", set: 1), weightKg: 20, reps: 0))
        #expect(WidgetCoaching.addRep(logging, yesterday) == WidgetInbox(day: Clock.saturdayStart, reps: 1))
    }

    @Test func aSnapshotFromAnotherDayOnlyShowsTheComingWorkout() {
        let ready = snapshot(.ready, [step("a", set: 1)])

        #expect(screen(ready, inbox(), at: Clock.day(1, hour: 9)) == .schedule(today: nil, next: next, canStart: false))
    }
}

// MARK: - Bringing the widget's start and sets into the workout

@MainActor
struct WidgetIntoWorkoutTests {
    private final class SyncSpy: CoachWidgetSyncing {
        var published: [CoachSnapshot] = []
        var waiting = WidgetInbox()
        func publish(_ snapshot: CoachSnapshot) { published.append(snapshot) }
        func takeInbox() -> WidgetInbox {
            defer { waiting.startedAt = nil; waiting.sets = [] }
            return waiting
        }
    }

    private func widgetSet(_ id: String, _ set: Int, kg: Double, reps: Int) -> WidgetInbox.LoggedSet {
        WidgetInbox.LoggedSet(
            exerciseID: id, setNumber: set, weightKg: kg, repetitions: reps, effort: "good", loggedAt: Clock.saturday)
    }

    private func makeMyPlan(store: SessionStoreStub, spy: SyncSpy) throws -> MyPlanViewModel {
        let plans = PlanStoreStub(plan: WorkoutPlan(
            goalID: "buildMuscle", workouts: [workout()], status: .active, startedOn: Clock.saturdayStart))
        let now = Clock.saturday
        return MyPlanViewModel(
            editPlan: EditWorkoutPlanUseCase(plans: plans, exercises: try JSONExerciseRepository()),
            workoutSessions: WorkoutSessionUseCase(sessions: store), goals: [],
            widget: CoachWidgetUseCase(sync: spy), now: { now })
    }

    private func startedStore() -> SessionStoreStub {
        let store = SessionStoreStub()
        store.logs[Clock.saturdayStart] = WorkoutLog(
            date: Clock.saturdayStart, weekday: 6, status: .inProgress, sets: [], startedAt: Clock.saturday)
        return store
    }

    private var todaysLog: (SessionStoreStub) -> WorkoutLog? { { $0.logs[Clock.saturdayStart] } }

    @Test func loadingPublishesTheSnapshotForTheWidget() throws {
        let spy = SyncSpy()
        let myPlan = try makeMyPlan(store: startedStore(), spy: spy)

        myPlan.load()

        #expect(spy.published.last?.phase == .logging)
        #expect(spy.published.last?.steps.count == 5)
    }

    @Test func setsFinishedOnTheWidgetAreLoggedInOrder() throws {
        let spy = SyncSpy()
        let store = startedStore()
        let myPlan = try makeMyPlan(store: store, spy: spy)
        spy.waiting = WidgetInbox(day: Clock.saturdayStart, sets: [
            widgetSet("machine-chest-press", 1, kg: 20, reps: 11),
            widgetSet("machine-chest-press", 2, kg: 20, reps: 10)
        ])

        myPlan.load()

        #expect(todaysLog(store)?.sets.map(\.setNumber) == [1, 2])
        #expect(todaysLog(store)?.sets.map(\.repetitions) == [11, 10])
        #expect(todaysLog(store)?.sets.map(\.effort) == [.good, .good])
        #expect(spy.published.last?.steps.count == 3)
    }

    @Test func aWorkoutStartedOnTheWidgetIsStartedAtThatTime() throws {
        let spy = SyncSpy()
        let store = SessionStoreStub()
        let myPlan = try makeMyPlan(store: store, spy: spy)
        let tappedStart = Clock.saturday.addingTimeInterval(-20 * 60)
        spy.waiting = WidgetInbox(
            day: Clock.saturdayStart, startedAt: tappedStart, sets: [widgetSet("machine-chest-press", 1, kg: 20, reps: 12)])

        myPlan.load()

        #expect(todaysLog(store)?.status == .inProgress)
        #expect(todaysLog(store)?.startedAt == tappedStart)
        #expect(todaysLog(store)?.sets.count == 1)
        #expect(spy.published.last?.phase == .logging)
    }

    @Test func aSetAlreadyLoggedIsNotLoggedTwice() throws {
        let spy = SyncSpy()
        let store = startedStore()
        let myPlan = try makeMyPlan(store: store, spy: spy)
        spy.waiting = WidgetInbox(day: Clock.saturdayStart, sets: [widgetSet("machine-chest-press", 1, kg: 20, reps: 10)])
        myPlan.load()
        spy.waiting = WidgetInbox(day: Clock.saturdayStart, sets: [widgetSet("machine-chest-press", 1, kg: 20, reps: 10)])

        myPlan.ingestWidget()

        #expect(todaysLog(store)?.sets.count == 1)
    }

    @Test func aSetThatIsNotTheNextOneIsLeftOut() throws {
        let spy = SyncSpy()
        let store = startedStore()
        let myPlan = try makeMyPlan(store: store, spy: spy)
        spy.waiting = WidgetInbox(day: Clock.saturdayStart, sets: [widgetSet("reverse-crunch", 1, kg: 0, reps: 10)])

        myPlan.load()

        #expect(todaysLog(store)?.sets.isEmpty == true)
    }

    @Test func whatWasDoneOnTheWidgetAnotherDayIsIgnored() throws {
        let spy = SyncSpy()
        let store = SessionStoreStub()
        let myPlan = try makeMyPlan(store: store, spy: spy)
        spy.waiting = WidgetInbox(
            day: Clock.day(-7), startedAt: Clock.day(-7, hour: 18), sets: [widgetSet("machine-chest-press", 1, kg: 20, reps: 10)])

        myPlan.load()

        #expect(todaysLog(store) == nil)
    }

    @Test func aRestRunningOnTheWidgetCarriesOnInTheApp() throws {
        let spy = SyncSpy()
        let myPlan = try makeMyPlan(store: startedStore(), spy: spy)
        let restEnds = Clock.saturday.addingTimeInterval(40)
        spy.waiting = WidgetInbox(
            day: Clock.saturdayStart, sets: [widgetSet("machine-chest-press", 1, kg: 20, reps: 10)], restEndsAt: restEnds)

        myPlan.load()

        #expect(myPlan.sessionViewModel(for: workout()).rest?.endsAt == restEnds)
        #expect(spy.published.last?.restEndsAt == restEnds)
    }

    @Test func aRestSkippedOnTheWidgetIsOverInTheApp() throws {
        let spy = SyncSpy()
        let myPlan = try makeMyPlan(store: startedStore(), spy: spy)
        spy.waiting = WidgetInbox(
            day: Clock.saturdayStart, sets: [widgetSet("machine-chest-press", 1, kg: 20, reps: 10)],
            restEndsAt: Clock.saturday.addingTimeInterval(-1))

        myPlan.load()

        #expect(myPlan.sessionViewModel(for: workout()).rest == nil)
        #expect(spy.published.last?.restEndsAt == nil)
    }

    @Test func aWorkoutStartedOnTheWidgetOpensOnItsLogInTheApp() throws {
        let spy = SyncSpy()
        let myPlan = try makeMyPlan(store: SessionStoreStub(), spy: spy)
        spy.waiting = WidgetInbox(day: Clock.saturdayStart, startedAt: Clock.saturday)

        myPlan.load()

        #expect(myPlan.openedWeekday == 6)
        #expect(myPlan.opensLog)
        #expect(myPlan.openRequests == 1)
    }

    @Test func nothingDoneOnTheWidgetOpensNothing() throws {
        let spy = SyncSpy()
        let myPlan = try makeMyPlan(store: startedStore(), spy: spy)
        spy.waiting = WidgetInbox(day: Clock.saturdayStart, reps: 4)

        myPlan.load()

        #expect(myPlan.openedWeekday == nil)
        #expect(myPlan.openRequests == 0)
    }

    @Test func aSetLoggedInTheAppShowsItsRestOnTheWidgetUntilSheSkipsIt() throws {
        let spy = SyncSpy()
        let myPlan = try makeMyPlan(store: startedStore(), spy: spy)
        myPlan.load()
        let session = myPlan.sessionViewModel(for: workout())
        session.weightText = "20"
        session.repsText = "10"

        session.completeSet()
        #expect(spy.published.last?.restEndsAt == session.rest?.endsAt)
        #expect(spy.published.last?.restEndsAt != nil)

        session.endRest()
        #expect(spy.published.last?.restEndsAt == nil)
    }
}
