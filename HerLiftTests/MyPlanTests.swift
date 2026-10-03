import Foundation
import Testing
@testable import HerLift

// MARK: - The week laid out for My Plan

@MainActor
struct PlanWeekTests {
    // Monday 28 September 2026 to Sunday 4 October 2026.
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    @Test func theWeekRunsFromMondayToSundayAroundToday() {
        let week = PlanWeek(plan: plan(startedOn: day(9, 28)), today: day(9, 30), calendar: calendar)

        #expect(week.days.map(\.weekday) == [1, 2, 3, 4, 5, 6, 7])
        #expect(week.days.map(\.date) == (0..<7).map { day(9, 28 + $0) })
    }

    @Test func aSundayStillBelongsToTheWeekThatStartedOnMonday() {
        let week = PlanWeek(plan: plan(startedOn: day(9, 28)), today: day(10, 4), calendar: calendar)

        #expect(week.days.first?.date == day(9, 28))
        #expect(week.days.last?.date == day(10, 4))
    }

    @Test func mondayIsAlwaysDayOneWhateverTheCalendarsFirstWeekday() {
        for firstWeekday in [1, 2] {
            var custom = calendar
            custom.firstWeekday = firstWeekday
            let weekdays = (0..<7).map { PlanWeek.mondayBasedWeekday(of: day(9, 28 + $0), calendar: custom) }
            #expect(weekdays == [1, 2, 3, 4, 5, 6, 7])
        }
    }

    @Test func eachDayIsADoneTodayUpcomingOrRestDay() {
        let week = PlanWeek(plan: plan(startedOn: day(9, 28)), today: day(9, 30), calendar: calendar)

        #expect(week.days.map(\.state) == [.upcoming, .rest, .today, .rest, .rest, .upcoming, .rest])
        #expect(week.workoutCount == 3)
        #expect(week.doneCount == 0)
        #expect(week.days[0].workout?.weekday == 1)
        #expect(week.days[1].workout == nil)
    }

    @Test func completedDaysAreMarkedDone() {
        let week = PlanWeek(
            plan: plan(startedOn: day(9, 28)), today: day(9, 30),
            completedDays: [day(9, 28), day(9, 30)], calendar: calendar)

        #expect(week.days.map(\.state) == [.done, .rest, .done, .rest, .rest, .upcoming, .rest])
        #expect(week.doneCount == 2)
        #expect(week.workoutCount == 3)
    }

    @Test func weeksCountFromTheStartDayAndStopAtTwelve() {
        func weekNumber(_ today: Date) -> Int {
            PlanWeek(plan: plan(startedOn: day(9, 28)), today: today, calendar: calendar).weekNumber
        }
        #expect(weekNumber(day(9, 28)) == 1)
        #expect(weekNumber(day(10, 4)) == 1)
        #expect(weekNumber(day(10, 5)) == 2)
        #expect(weekNumber(day(10, 7)) == 2)
        #expect(weekNumber(day(12, 21)) == 12)
        #expect(weekNumber(day(12, 31)) == 12)
    }

    @Test func daysBeforeThePlanStartedHaveNoWorkout() {
        // Accepted on Wednesday, so that Monday's workout is not part of the plan yet.
        let week = PlanWeek(plan: plan(startedOn: day(9, 30)), today: day(10, 3), calendar: calendar)

        #expect(week.days.map(\.state) == [.rest, .rest, .upcoming, .rest, .rest, .today, .rest])
        #expect(week.workoutCount == 2)
        #expect(week.weekNumber == 1)
    }

    @Test func aPlanWithoutAStartDateStartsToday() {
        let week = PlanWeek(plan: plan(startedOn: nil), today: day(9, 30), calendar: calendar)

        #expect(week.days.map(\.state) == [.rest, .rest, .today, .rest, .rest, .upcoming, .rest])
        #expect(week.weekNumber == 1)
    }

    private func day(_ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day))!
    }

    /// Workouts on Monday, Wednesday and Saturday.
    private func plan(startedOn: Date?) -> WorkoutPlan {
        let exercise = try! JSONExerciseRepository().exercises[0]
        func workout(_ weekday: Int) -> PlannedWorkout {
            PlannedWorkout(weekday: weekday, categoryIDs: ["legs"], exercises: [WorkoutExercise(exercise: exercise, sets: 3)])
        }
        return WorkoutPlan(
            goalID: "buildMuscle", workouts: [workout(1), workout(3), workout(6)],
            status: startedOn == nil ? .draft : .active, startedOn: startedOn)
    }
}

// MARK: - Home and reopening the app

@MainActor
struct MyPlanViewModelTests {
    @Test func loadReadsTheStoredPlan() throws {
        let store = PlanStoreStub(plan: storedPlan())
        let viewModel = try makeMyPlan(store)
        #expect(viewModel.plan == nil)

        viewModel.load()

        #expect(viewModel.plan == storedPlan())
        #expect(viewModel.error == nil)
    }

    @Test func withoutAStoredPlanThereIsNothingToShow() throws {
        let viewModel = try makeMyPlan(PlanStoreStub())
        viewModel.load()

        #expect(viewModel.plan == nil)
        #expect(viewModel.week == nil)
    }

    @Test func aStorageFailureIsReported() throws {
        let store = PlanStoreStub(plan: storedPlan())
        store.fails = true
        let viewModel = try makeMyPlan(store)

        viewModel.load()

        #expect(viewModel.error == .couldNotLoadPlan)
    }

    @Test func theWeekIsBuiltAroundTheClockTime() throws {
        let startedOn = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_790_000_000))
        var plan = storedPlan()
        plan.startedOn = startedOn
        let viewModel = try makeMyPlan(PlanStoreStub(plan: plan), now: startedOn.addingTimeInterval(8 * 24 * 3600))

        viewModel.load()

        #expect(viewModel.week?.weekNumber == 2)
    }

    @Test func theGoalTitleComesFromTheGoalList() throws {
        let viewModel = try makeMyPlan(PlanStoreStub())
        #expect(viewModel.goalTitle(for: storedPlan()) == "Build muscle")
    }

    @Test func reopeningTheAppRestoresOnlyAPlanWaitingForAcceptance() throws {
        let draftStore = PlanStoreStub(plan: storedPlan())
        let draftViewModel = try makeGeneratePlan(draftStore)
        draftViewModel.restore()
        guard case .ready(let draft) = draftViewModel.state else { Issue.record("expected the draft"); return }
        #expect(draft.status == .draft)

        var active = storedPlan()
        active.status = .active
        let activeViewModel = try makeGeneratePlan(PlanStoreStub(plan: active))
        activeViewModel.restore()
        guard case .idle = activeViewModel.state else { Issue.record("an accepted plan belongs to My Plan"); return }

        let emptyViewModel = try makeGeneratePlan(PlanStoreStub())
        emptyViewModel.restore()
        guard case .idle = emptyViewModel.state else { Issue.record("nothing to restore"); return }
    }

    @Test func acceptReportsWhetherThePlanIsNowActive() throws {
        let store = PlanStoreStub(plan: storedPlan())
        let viewModel = try makeGeneratePlan(store)

        #expect(viewModel.accept())
        #expect(!viewModel.accept())
        #expect(viewModel.error == .planAlreadyAccepted)
    }

    private func storedPlan() -> WorkoutPlan {
        let exercise = try! JSONExerciseRepository().exercises[0]
        return WorkoutPlan(goalID: "buildMuscle", workouts: [
            PlannedWorkout(weekday: 1, categoryIDs: ["legs"], exercises: [WorkoutExercise(exercise: exercise, sets: 3)])
        ])
    }

    private let goals = [Goal(id: "buildMuscle", title: "Build muscle", requiresTargetWeight: false)]

    private func makeMyPlan(_ store: PlanStoreStub, now: Date = Date()) throws -> MyPlanViewModel {
        MyPlanViewModel(
            editPlan: EditWorkoutPlanUseCase(plans: store, exercises: try JSONExerciseRepository()),
            workoutSessions: WorkoutSessionUseCase(sessions: SessionStoreStub()), goals: goals, now: { now })
    }

    private func makeGeneratePlan(_ store: PlanStoreStub) throws -> GeneratePlanViewModel {
        let exercises = try JSONExerciseRepository()
        return GeneratePlanViewModel(
            createPlan: CreateWorkoutPlanUseCase(
                patterns: try JSONTrainingPatternRepository(), exercises: exercises, plans: store),
            editPlan: EditWorkoutPlanUseCase(plans: store, exercises: exercises),
            goals: goals)
    }
}

// MARK: - Opening today's workout from a link

@MainActor
struct OpenTodaysWorkoutTests {
    private let calendar = Calendar.current
    /// Saturday 3 October 2026, 14:00 in the device's time zone.
    private var saturday: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 3, hour: 14))! }

    private func makeMyPlan(weekdays: [PlannedWorkout]? = nil, store: SessionStoreStub? = nil) throws -> MyPlanViewModel {
        let store = store ?? SessionStoreStub()
        let plans = PlanStoreStub(plan: WorkoutPlan(
            goalID: "buildMuscle", workouts: weekdays ?? [workout()], status: .active, startedOn: calendar.startOfDay(for: saturday)))
        let now = saturday
        return MyPlanViewModel(
            editPlan: EditWorkoutPlanUseCase(plans: plans, exercises: try JSONExerciseRepository()),
            workoutSessions: WorkoutSessionUseCase(sessions: store), goals: [], now: { now })
    }

    @Test func aWorkoutNotStartedYetOpensItsDay() throws {
        let myPlan = try makeMyPlan()

        myPlan.openTodaysWorkout()

        #expect(myPlan.openedWeekday == 6)
        #expect(!myPlan.opensLog)
    }

    @Test func aWorkoutInProgressOpensStraightToItsLog() throws {
        let store = SessionStoreStub()
        let day = calendar.startOfDay(for: saturday)
        store.logs[day] = WorkoutLog(date: day, weekday: 6, status: .inProgress, sets: [])
        let myPlan = try makeMyPlan(store: store)

        myPlan.openTodaysWorkout()

        #expect(myPlan.openedWeekday == 6)
        #expect(myPlan.opensLog)
    }

    @Test func tappingADayAfterwardsDoesNotSkipItsLog() throws {
        let store = SessionStoreStub()
        let day = calendar.startOfDay(for: saturday)
        store.logs[day] = WorkoutLog(date: day, weekday: 6, status: .inProgress, sets: [])
        let myPlan = try makeMyPlan(store: store)
        myPlan.openTodaysWorkout()

        myPlan.open(weekday: 6)

        #expect(!myPlan.opensLog)
    }

    @Test func aRestDayOpensNothing() throws {
        let sunday = PlannedWorkout(weekday: 7, categoryIDs: workout().categoryIDs, exercises: workout().exercises)
        let myPlan = try makeMyPlan(weekdays: [sunday])

        myPlan.openTodaysWorkout()

        #expect(myPlan.openedWeekday == nil)
    }
}
