import SwiftUI
import UIKit
import UserNotifications
import UserNotificationsUI

/// The view shown when she presses and holds a workout reminder. It replaces the plain title and text with
/// how long until she trains and what she trains, so a glance is enough to know it is almost time.
final class NotificationViewController: UIViewController, UNNotificationContentExtension {
    private var hosting: UIHostingController<ReminderContentView>?

    func didReceive(_ notification: UNNotification) {
        let content = notification.request.content
        let view = ReminderContentView(workout: ReminderContent(userInfo: content.userInfo), fallbackText: content.body)

        hosting?.willMove(toParent: nil)
        hosting?.view.removeFromSuperview()
        hosting?.removeFromParent()

        let controller = UIHostingController(rootView: view)
        controller.view.backgroundColor = .clear
        addChild(controller)
        self.view.addSubview(controller.view)
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            controller.view.topAnchor.constraint(equalTo: self.view.topAnchor),
            controller.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor)
        ])
        controller.didMove(toParent: self)
        hosting = controller

        // The notification is as tall as the workout.
        let width = self.view.bounds.width
        let fitted = controller.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
        preferredContentSize = CGSize(width: width, height: fitted.height)
    }
}
