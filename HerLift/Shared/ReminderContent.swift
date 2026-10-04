import Foundation

/// What a workout reminder says about the workout, carried inside the notification so the notification's own view
/// can show it without the app: what she trains, when it starts and how long it takes.
nonisolated struct ReminderContent: Codable, Equatable, Sendable {
    /// The notification category the reminder's own view is registered for.
    static let category = "HERLIFT_WORKOUT_REMINDER"
    /// The reminder's button that opens today's workout.
    static let startActionID = "herlift.reminder.start"
    private static let userInfoKey = "herlift.reminder"

    /// "Chest · Core"
    let title: String
    let minutes: Int
    /// Her training time on the day of the workout.
    let startsAt: Date

    /// "About 40 min"
    var durationLine: String { "About \(minutes) min" }

    /// The content as a notification's user info.
    func userInfo() -> [String: Any] {
        guard let data = try? Self.encoder.encode(self), let text = String(data: data, encoding: .utf8) else { return [:] }
        return [Self.userInfoKey: text]
    }

    /// The content a notification carries, or nil when it carries none.
    init?(userInfo: [AnyHashable: Any]) {
        guard let text = userInfo[Self.userInfoKey] as? String,
              let content = try? Self.decoder.decode(ReminderContent.self, from: Data(text.utf8))
        else { return nil }
        self = content
    }

    init(title: String, minutes: Int, startsAt: Date) {
        self.title = title
        self.minutes = minutes
        self.startsAt = startsAt
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }
}
