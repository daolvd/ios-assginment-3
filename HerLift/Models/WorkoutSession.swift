import Foundation
import SwiftData

/// One day's workout. A day has at most one.
@Model
nonisolated final class WorkoutSession {
    @Attribute(.unique) var id: UUID
    /// The start of the day.
    var date: Date
    var weekday: Int
    var statusRaw: String
    var startedAt: Date?
    var completedAt: Date?
    @Relationship(deleteRule: .cascade, inverse: \ExerciseSet.session) var sets: [ExerciseSet] = []

    init(
        id: UUID = UUID(), date: Date, weekday: Int, statusRaw: String, startedAt: Date? = nil,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.date = date
        self.weekday = weekday
        self.statusRaw = statusRaw
        self.startedAt = startedAt
        self.completedAt = completedAt
    }
}
