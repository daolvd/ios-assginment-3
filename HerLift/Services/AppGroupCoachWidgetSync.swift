import Foundation
import WidgetKit

/// Shares the snapshot and the widget's inbox through the App Group and refreshes the widget when it changes.
@MainActor
struct AppGroupCoachWidgetSync: CoachWidgetSyncing {
    func publish(_ snapshot: CoachSnapshot) {
        CoachFiles.writeSnapshot(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    func takeInbox() -> WidgetInbox {
        var taken = WidgetInbox()
        CoachFiles.updateInbox { inbox in
            taken = inbox
            var updated = inbox
            updated.startedAt = nil
            updated.sets = []
            return updated
        }
        return taken
    }
}
