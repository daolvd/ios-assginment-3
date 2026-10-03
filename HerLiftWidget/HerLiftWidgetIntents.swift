import AppIntents
import WidgetKit

/// The widget's buttons. Each one changes the shared inbox with the same rules the app's tests cover; WidgetKit
/// redraws the widget when `perform` returns.

struct StartWorkoutIntent: AppIntent {
    static let title: LocalizedStringResource = "Start workout"
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        guard let snapshot = CoachFiles.readSnapshot() else { return .result() }
        CoachFiles.updateInbox { WidgetCoaching.start(snapshot, $0, now: Date()) }
        return .result()
    }
}

struct AddRepIntent: AppIntent {
    static let title: LocalizedStringResource = "Add a rep"
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        guard let snapshot = CoachFiles.readSnapshot() else { return .result() }
        CoachFiles.updateInbox { WidgetCoaching.addRep(snapshot, $0) }
        return .result()
    }
}

struct ResetRepsIntent: AppIntent {
    static let title: LocalizedStringResource = "Reset reps"
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        guard let snapshot = CoachFiles.readSnapshot() else { return .result() }
        CoachFiles.updateInbox { WidgetCoaching.reset(snapshot, $0) }
        return .result()
    }
}

struct CompleteSetIntent: AppIntent {
    static let title: LocalizedStringResource = "Complete set"
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        guard let snapshot = CoachFiles.readSnapshot() else { return .result() }
        CoachFiles.updateInbox { WidgetCoaching.complete(snapshot, $0, now: Date()) }
        return .result()
    }
}

struct SkipRestIntent: AppIntent {
    static let title: LocalizedStringResource = "Skip rest"
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        guard let snapshot = CoachFiles.readSnapshot() else { return .result() }
        CoachFiles.updateInbox { WidgetCoaching.skipRest(snapshot, $0) }
        return .result()
    }
}
