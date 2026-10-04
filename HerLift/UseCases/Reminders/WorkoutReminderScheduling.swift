import Foundation

/// Puts workout reminders on the phone. Scheduling never fails the caller: if she has not allowed
/// notifications, nothing is scheduled and everything else carries on.
@MainActor
protocol WorkoutReminderScheduling {
    /// Replaces the scheduled reminder, asking for permission the first time. Nil removes it.
    func replaceReminder(with reminder: WorkoutReminder?)
    func sendTestReminder(_ reminder: WorkoutReminder)
}

/// Used where no notifications are wanted, such as previews.
@MainActor
struct NoReminders: WorkoutReminderScheduling {
    func replaceReminder(with reminder: WorkoutReminder?) {}
    func sendTestReminder(_ reminder: WorkoutReminder) {}
}

extension WorkoutReminderUseCase {
    /// A reminder use case that schedules nothing.
    static func disabled() -> WorkoutReminderUseCase {
        WorkoutReminderUseCase(scheduler: NoReminders(), time: InMemoryTrainingTime())
    }
}
