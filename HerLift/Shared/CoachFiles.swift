import Foundation

/// The two small files the app and the widget share through the App Group: the snapshot the app writes, and the
/// inbox the widget writes. Reads never fail the caller; a missing or unreadable file just means "nothing yet".
nonisolated enum CoachFiles {
    static let appGroupID = "group.com.van.assignment3.HerLift"
    private static let snapshotName = "CoachSnapshot.json"
    private static let inboxName = "WidgetInbox.json"

    static func readSnapshot() -> CoachSnapshot? {
        guard let url = fileURL(snapshotName) else { return nil }
        return decode(CoachSnapshot.self, at: url)
    }

    static func writeSnapshot(_ snapshot: CoachSnapshot) {
        guard let url = fileURL(snapshotName), let data = try? encoder.encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func readInbox() -> WidgetInbox {
        guard let url = fileURL(inboxName) else { return WidgetInbox() }
        return decode(WidgetInbox.self, at: url) ?? WidgetInbox()
    }

    /// Changes the inbox as one step, so the app and the widget never overwrite each other's change.
    @discardableResult
    static func updateInbox(_ change: (WidgetInbox) -> WidgetInbox) -> WidgetInbox {
        guard let url = fileURL(inboxName) else { return WidgetInbox() }
        var result = WidgetInbox()
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forMerging, error: &coordinationError) { url in
            result = change(decode(WidgetInbox.self, at: url) ?? WidgetInbox())
            if let data = try? encoder.encode(result) { try? data.write(to: url, options: .atomic) }
        }
        return result
    }

    private static func fileURL(_ name: String) -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(name)
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return encoder
    }

    private static func decode<Value: Decodable>(_ type: Value.Type, at url: URL) -> Value? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try? decoder.decode(type, from: data)
    }
}
