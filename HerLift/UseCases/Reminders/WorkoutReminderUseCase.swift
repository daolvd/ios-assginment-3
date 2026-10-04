import Foundation

/// Where her training time is kept, as minutes after midnight.
@MainActor
protocol TrainingTimeStoring {
    var trainingMinute: Int? { get set }
}

/// Keeps her workout reminder in step with her plan and her training time.
@MainActor
struct WorkoutReminderUseCase {
    private let scheduler: any WorkoutReminderScheduling
    private var time: any TrainingTimeStoring

    init(scheduler: any WorkoutReminderScheduling, time: any TrainingTimeStoring) {
        self.scheduler = scheduler
        self.time = time
    }

    /// Her training time as minutes after midnight.
    var trainingMinute: Int { time.trainingMinute ?? WorkoutReminderRule.defaultTrainingMinute }

    mutating func setTrainingMinute(_ minute: Int) {
        time.trainingMinute = min(max(minute, 0), 24 * 60 - 1)
    }

    /// Schedules the reminder for the next workout, or removes it while there is no accepted plan.
    func refresh(plan: WorkoutPlan?, completedDays: Set<Date>, now: Date) {
        let reminder = plan.flatMap {
            WorkoutReminderRule.next(for: $0, completedDays: completedDays, now: now, trainingMinute: trainingMinute)
        }
        scheduler.replaceReminder(with: reminder)
    }

    /// Sends a reminder in a few seconds, to show how it looks.
    func sendTest(plan: WorkoutPlan?, now: Date) {
        scheduler.sendTestReminder(WorkoutReminderRule.test(for: plan, now: now))
    }
}

/// Used where no reminders are wanted, such as previews and most tests.
@MainActor
final class InMemoryTrainingTime: TrainingTimeStoring {
    var trainingMinute: Int?
    init(_ trainingMinute: Int? = nil) { self.trainingMinute = trainingMinute }
}
