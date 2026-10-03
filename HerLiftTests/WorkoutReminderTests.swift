import Foundation
import Testing
@testable import HerLift

// MARK: - When the reminder fires and what it says

@MainActor
struct WorkoutReminderTests {
    // Monday 28 September 2026 to Sunday 4 October 2026; she trains on Monday, Wednesday and Saturday.
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func time(_ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    private func plan(status: PlanStatus = .active, startedOn: Date? = nil) -> WorkoutPlan {
        let exercises = try! JSONExerciseRepository().exercises.prefix(4).map { WorkoutExercise(exercise: $0, sets: 3) }
        return WorkoutPlan(
            goalID: "buildMuscle",
            workouts: [1, 3, 6].map { PlannedWorkout(weekday: $0, categoryIDs: ["legs"], exercises: Array(exercises)) },
            status: status, startedOn: startedOn ?? time(9, 28))
    }

    private func next(
        _ plan: WorkoutPlan, now: Date, done: Set<Date> = [], trainingMinute: Int = 18 * 60
    ) -> WorkoutReminder? {
        WorkoutReminderRule.next(
            for: plan, completedDays: done, now: now, trainingMinute: trainingMinute, calendar: calendar)
    }

    @Test func theReminderComesThirtyMinutesBeforeHerTrainingTime() {
        let reminder = next(plan(), now: time(9, 28, 8))

        #expect(reminder?.fireDate == time(9, 28, 17, 30))
    }

    @Test func aChangedTrainingTimeMovesTheReminder() {
        let reminder = next(plan(), now: time(9, 28, 6), trainingMinute: 6 * 60 + 45)

        #expect(reminder?.fireDate == time(9, 28, 6, 15))
    }

    @Test func aTrainingTimeShortlyAfterMidnightRemindsThePreviousEvening() {
        let reminder = next(plan(), now: time(9, 27, 12), trainingMinute: 15)

        #expect(reminder?.fireDate == time(9, 27, 23, 45))
    }

    @Test func afterTodaysReminderTimeTheNextTrainingDayIsUsed() {
        let reminder = next(plan(), now: time(9, 28, 17, 45))

        #expect(reminder?.fireDate == time(9, 30, 17, 30))
    }

    @Test func aFinishedWorkoutIsNotRemindedAbout() {
        let reminder = next(plan(), now: time(9, 28, 8), done: [time(9, 28)])

        #expect(reminder?.fireDate == time(9, 30, 17, 30))
    }

    @Test func theWeekWrapsToTheNextMondayAfterSaturday() {
        let reminder = next(plan(), now: time(10, 3, 19))

        #expect(reminder?.fireDate == time(10, 5, 17, 30))
    }

    @Test func daysBeforeThePlanStartedAreSkipped() {
        let reminder = next(plan(startedOn: time(9, 30)), now: time(9, 28, 8))

        #expect(reminder?.fireDate == time(9, 30, 17, 30))
    }

    @Test func aDraftPlanHasNoReminder() {
        #expect(next(plan(status: .draft), now: time(9, 28, 8)) == nil)
    }

    @Test func theReminderNamesTheWorkoutAndItsFirstThreeExercises() throws {
        let reminder = try #require(next(plan(), now: time(9, 28, 8)))
        let names = try JSONExerciseRepository().exercises.prefix(3).map(\.name)

        #expect(reminder.title == "Workout in 30 minutes")
        #expect(reminder.body.contains("Legs"))
        #expect(reminder.body.contains(names.joined(separator: ", ")))
        #expect(!reminder.body.contains(try JSONExerciseRepository().exercises[3].name))
    }

    @Test func theReminderCarriesWhatTheWorkoutIsAndWhenItStartsForItsOwnView() throws {
        let reminder = try #require(next(plan(), now: time(9, 28, 8)))
        let content = try #require(reminder.content)

        #expect(content.title == "Legs")
        #expect(content.startsAt == time(9, 28, 18))
        #expect(content.minutes == plan().workouts[0].estimatedMinutes)
        #expect(content.durationLine == "About \(content.minutes) min")
    }

    @Test func theWorkoutStartsAtHerTrainingTimeWhileTheNotificationComesHalfAnHourBefore() throws {
        let reminder = try #require(next(plan(), now: time(9, 28, 5), trainingMinute: 6 * 60 + 45))

        #expect(reminder.fireDate == time(9, 28, 6, 15))
        #expect(reminder.content?.startsAt == time(9, 28, 6, 45))
    }

    @Test func theWorkoutSurvivesTheTripThroughTheNotification() throws {
        let content = try #require(next(plan(), now: time(9, 28, 8))?.content)

        #expect(ReminderContent(userInfo: content.userInfo()) == content)
        #expect(ReminderContent(userInfo: [:]) == nil)
        #expect(ReminderContent(userInfo: ["herlift.reminder": "not a workout"]) == nil)
    }

    @Test func theReminderIsSentForTheCategoryItsOwnViewIsRegisteredFor() {
        #expect(ReminderContent.category == "HERLIFT_WORKOUT_REMINDER")
        #expect(ReminderContent.startActionID == "herlift.reminder.start")
    }

    @Test func aTestReminderFiresShortlyFromNow() {
        let reminder = WorkoutReminderRule.test(for: plan(), now: time(9, 28, 8))

        #expect(reminder.fireDate == time(9, 28, 8).addingTimeInterval(5))
    }
}

// MARK: - Her training time and the scheduled reminder

@MainActor
struct WorkoutReminderUseCaseTests {
    private final class SchedulerSpy: WorkoutReminderScheduling {
        var replaced: [WorkoutReminder?] = []
        var tests: [WorkoutReminder] = []
        func replaceReminder(with reminder: WorkoutReminder?) { replaced.append(reminder) }
        func sendTestReminder(_ reminder: WorkoutReminder) { tests.append(reminder) }
    }

    @Test func untilSheChoosesATimeItIsSixPm() {
        let useCase = WorkoutReminderUseCase(scheduler: SchedulerSpy(), time: InMemoryTrainingTime())

        #expect(useCase.trainingMinute == 18 * 60)
    }

    @Test func theChosenTimeIsKeptAndStaysInsideTheDay() {
        let store = InMemoryTrainingTime()
        var useCase = WorkoutReminderUseCase(scheduler: SchedulerSpy(), time: store)

        useCase.setTrainingMinute(7 * 60 + 30)
        #expect(store.trainingMinute == 450)
        useCase.setTrainingMinute(5000)
        #expect(store.trainingMinute == 24 * 60 - 1)
        useCase.setTrainingMinute(-5)
        #expect(store.trainingMinute == 0)
    }

    @Test func withoutAPlanTheScheduledReminderIsRemoved() {
        let spy = SchedulerSpy()
        let useCase = WorkoutReminderUseCase(scheduler: spy, time: InMemoryTrainingTime())

        useCase.refresh(plan: nil, completedDays: [], now: Date())

        #expect(spy.replaced.count == 1)
        #expect(spy.replaced.first! == nil)
    }
}
