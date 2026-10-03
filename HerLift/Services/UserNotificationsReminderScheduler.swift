import Foundation
import UserNotifications

/// Schedules the workout reminder with the system. There is one reminder at a time: scheduling a new one
/// replaces the old one.
@MainActor
final class UserNotificationsReminderScheduler: WorkoutReminderScheduling {
    static let reminderID = "herlift.workout-reminder"
    static let testID = "herlift.workout-reminder.test"
    /// The category the notification extension will recognise.
    static let category = "HERLIFT_WORKOUT_REMINDER"

    private let center = UNUserNotificationCenter.current()
    private let calendar = Calendar.current

    func replaceReminder(with reminder: WorkoutReminder?) {
        Task {
            center.removePendingNotificationRequests(withIdentifiers: [Self.reminderID])
            guard let reminder, await isAllowed() else { return }
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            try? await center.add(request(Self.reminderID, reminder, trigger))
        }
    }

    func sendTestReminder(_ reminder: WorkoutReminder) {
        Task {
            guard await isAllowed() else { return }
            let seconds = max(1, reminder.fireDate.timeIntervalSinceNow)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
            try? await center.add(request(Self.testID, reminder, trigger))
        }
    }

    private func request(_ id: String, _ reminder: WorkoutReminder, _ trigger: UNNotificationTrigger)
        -> UNNotificationRequest
    {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.body
        content.sound = .default
        content.categoryIdentifier = Self.category
        return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
    }

    /// Asks for permission the first time; afterwards only reads the answer.
    private func isAllowed() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        default:
            return false
        }
    }
}

/// Her training time, kept on the phone.
@MainActor
struct UserDefaultsTrainingTime: TrainingTimeStoring {
    private static let key = "herlift.training-minute"

    var trainingMinute: Int? {
        get { UserDefaults.standard.object(forKey: Self.key) as? Int }
        set { UserDefaults.standard.set(newValue, forKey: Self.key) }
    }
}

/// Shows a reminder as a banner even while the app is open, so a test reminder is visible.
final class ReminderPresenter: NSObject, UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
