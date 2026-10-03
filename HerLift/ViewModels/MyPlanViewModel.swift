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
    @ObservationIgnored private let editPlan: EditWorkoutPlanUseCase
    @ObservationIgnored private let workoutSessions: WorkoutSessionUseCase
    @ObservationIgnored private let reminders: WorkoutReminderUseCase
    @ObservationIgnored let now: () -> Date
    /// One session view model per workout, so its state survives the screen being redrawn.
    @ObservationIgnored private var sessionViewModels: [Int: WorkoutSessionViewModel] = [:]

    init(
        editPlan: EditWorkoutPlanUseCase, workoutSessions: WorkoutSessionUseCase, goals: [Goal],
        reminders: WorkoutReminderUseCase? = nil, now: @escaping () -> Date = { Date() }
    ) {
        self.editPlan = editPlan
        self.workoutSessions = workoutSessions
        self.reminders = reminders ?? .disabled()
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
    }

    var week: PlanWeek? {
        plan.map { PlanWeek(plan: $0, today: now(), completedDays: completedDays) }
    }

    /// The session for a workout, picking up one already started today.
    func sessionViewModel(for workout: PlannedWorkout) -> WorkoutSessionViewModel {
        if let existing = sessionViewModels[workout.weekday] { return existing }
        let created = WorkoutSessionViewModel(workout: workout, useCase: workoutSessions, editPlan: editPlan, now: now)
        created.load()
        sessionViewModels[workout.weekday] = created
        return created
    }

    func goalTitle(for plan: WorkoutPlan) -> String {
        goals.first { $0.id == plan.goalID }?.title ?? plan.goalID
    }
}
