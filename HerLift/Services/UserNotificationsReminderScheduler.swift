import Foundation
import UserNotifications

/// Schedules the workout reminder with the system. There is one reminder at a time: scheduling a new one
/// replaces the old one.
@MainActor
final class UserNotificationsReminderScheduler: WorkoutReminderScheduling {
    static let reminderID = "herlift.workout-reminder"
    static let testID = "herlift.workout-reminder.test"
    /// Registers the reminder's category, with Start workout as its button. The reminder's own view is shown for
    /// this category.
    static func registerCategory() {
        let start = UNNotificationAction(
            identifier: ReminderContent.startActionID, title: "Start workout", options: [.foreground])
        let category = UNNotificationCategory(
            identifier: ReminderContent.category, actions: [start], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

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
        content.categoryIdentifier = ReminderContent.category
        if let workout = reminder.content { content.userInfo = workout.userInfo() }
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

/// Shows a reminder as a banner even while the app is open, so a test reminder is visible, and opens today's
/// workout when she taps the reminder or its Start workout button. The delegate methods run on the main actor:
/// the system finishes a tap on the main thread and stops the app if it is finished anywhere else.
@MainActor
final class ReminderPresenter: NSObject, UNUserNotificationCenterDelegate {
    /// Opens today's workout in the app.
    var onOpenWorkout: () -> Void = {}

    func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse
    ) async {
        let action = response.actionIdentifier
        guard response.notification.request.content.categoryIdentifier == ReminderContent.category,
              action == UNNotificationDefaultActionIdentifier || action == ReminderContent.startActionID
        else { return }
        onOpenWorkout()
    }
}
