import Foundation
import Observation

/// The home screen's data: the stored plan laid out for the current week.
@MainActor
@Observable
final class MyPlanViewModel {
    private(set) var plan: WorkoutPlan?
    /// The days she finished a workout.
    private(set) var completedDays: Set<Date> = []
    var error: WorkoutPlanError?
    let goals: [Goal]
    /// The workout day that is open, by weekday.
    var openedWeekday: Int?
    /// The open workout day goes straight to its log, because the workout was already started.
    private(set) var opensLog = false
    /// Counts the times today's workout was opened for her, so the screen holding My Plan can come to the front.
    private(set) var openRequests = 0
    @ObservationIgnored private let editPlan: EditWorkoutPlanUseCase
    @ObservationIgnored private let workoutSessions: WorkoutSessionUseCase
    @ObservationIgnored private let reminders: WorkoutReminderUseCase
    @ObservationIgnored private let widget: CoachWidgetUseCase
    @ObservationIgnored let now: () -> Date
    /// One session view model per workout, so its state survives the screen being redrawn.
    @ObservationIgnored private var sessionViewModels: [Int: WorkoutSessionViewModel] = [:]

    init(
        editPlan: EditWorkoutPlanUseCase, workoutSessions: WorkoutSessionUseCase, goals: [Goal],
        reminders: WorkoutReminderUseCase? = nil, widget: CoachWidgetUseCase? = nil, now: @escaping () -> Date = { Date() }
    ) {
        self.editPlan = editPlan
        self.workoutSessions = workoutSessions
        self.reminders = reminders ?? .disabled()
        self.widget = widget ?? .disabled()
        self.goals = goals
        self.now = now
    }

    /// Reads the stored plan and the finished workouts again; the plan is nil when none has been created.
    func load() {
        sessionViewModels = [:]
        completedDays = (try? workoutSessions.completedDays()) ?? []
        do {
            plan = try editPlan.currentPlan()
            error = nil
        } catch {
            self.error = error
        }
        reminders.refresh(plan: plan, completedDays: completedDays, now: now())
        ingestWidget()
    }

    /// Records what she did on the widget: a workout she started there, the sets she finished and its rest. Only
    /// today's counts. When the workout was started or moved on there, it opens on the same step here. Then
    /// refreshes the widget.
    func ingestWidget() {
        let inbox = widget.takeInbox()
        if let workout = todaysWorkout, let day = inbox.day, Calendar.current.isDate(day, inSameDayAs: now()) {
            let session = sessionViewModel(for: workout)
            if let startedAt = inbox.startedAt, session.log == nil { session.start(at: startedAt) }
            session.applyWidget(sets: inbox.sets, restEndsAt: inbox.restEndsAt)
            if session.isInProgress, inbox.startedAt != nil || !inbox.sets.isEmpty {
                opensLog = true
                openedWeekday = workout.weekday
                openRequests += 1
            }
        }
        publishWidget()
    }

    private var todaysWorkout: PlannedWorkout? {
        week?.days.first { Calendar.current.isDate($0.date, inSameDayAs: now()) }?.workout
    }

    private func publishWidget() {
        let log = (try? workoutSessions.currentLog(on: now())) ?? nil
        let rest = todaysWorkout.flatMap { sessionViewModels[$0.weekday]?.rest }
        widget.publish(
            plan: plan, log: log, completedDays: completedDays, now: now(), trainingMinute: reminders.trainingMinute,
            restEndsAt: rest?.endsAt)
    }

    /// Opens a day by tapping it.
    func open(weekday: Int) {
        opensLog = false
        openedWeekday = weekday
    }

    /// Opens today's workout, straight to its log when it was already started. Does nothing on a rest day.
    func openTodaysWorkout() {
        load()
        guard let day = week?.days.first(where: { Calendar.current.isDate($0.date, inSameDayAs: now()) }),
              let workout = day.workout else { return }
        opensLog = sessionViewModel(for: workout).isInProgress
        openedWeekday = day.weekday
        openRequests += 1
    }

    var week: PlanWeek? {
        plan.map { PlanWeek(plan: $0, today: now(), completedDays: completedDays) }
    }

    /// The session for a workout, picking up one already started today.
    func sessionViewModel(for workout: PlannedWorkout) -> WorkoutSessionViewModel {
        if let existing = sessionViewModels[workout.weekday] { return existing }
        let created = WorkoutSessionViewModel(workout: workout, useCase: workoutSessions, editPlan: editPlan, now: now)
        created.load()
        created.onChange = { [weak self] in self?.publishWidget() }
        sessionViewModels[workout.weekday] = created
        return created
    }

    func goalTitle(for plan: WorkoutPlan) -> String {
        goals.first { $0.id == plan.goalID }?.title ?? plan.goalID
    }
}
