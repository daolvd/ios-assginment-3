import Foundation

/// Hands the widget what it needs and takes back what she did on it.
@MainActor
protocol CoachWidgetSyncing {
    func publish(_ snapshot: CoachSnapshot)
    /// What she did on the widget: its Start, the sets she finished and its rest, which are removed from the
    /// shared inbox.
    func takeInbox() -> WidgetInbox
}

/// Keeps the widget in step with the plan and today's workout, and brings its start and sets back into the workout.
@MainActor
struct CoachWidgetUseCase {
    private let sync: any CoachWidgetSyncing

    init(sync: any CoachWidgetSyncing) { self.sync = sync }

    /// `restEndsAt` is when the rest the app is running ends.
    func publish(
        plan: WorkoutPlan?, log: WorkoutLog?, completedDays: Set<Date>, now: Date, trainingMinute: Int,
        restEndsAt: Date?
    ) {
        sync.publish(CoachSnapshotBuilder.make(
            plan: plan, log: log, completedDays: completedDays, now: now, trainingMinute: trainingMinute,
            restEndsAt: restEndsAt))
    }

    func takeInbox() -> WidgetInbox { sync.takeInbox() }

    /// A widget use case that shares nothing, such as in previews and most tests.
    static func disabled() -> CoachWidgetUseCase { CoachWidgetUseCase(sync: NoWidget()) }
}

@MainActor
private struct NoWidget: CoachWidgetSyncing {
    func publish(_ snapshot: CoachSnapshot) {}
    func takeInbox() -> WidgetInbox { WidgetInbox() }
}
