import Foundation
import SwiftData

/// The one stored plan. It keeps only the goal and the days; exercises are referenced by catalogue ID.
@Model
nonisolated final class TrainingPlan {
    @Attribute(.unique) var id: UUID
    var goalID: String
    var createdAt: Date
    /// "draft" or "active". The default lets stores created before this field existed open as drafts.
    var statusRaw: String = "draft"
    var startedOn: Date?
    /// Fat-loss forecast, only for that goal.
    var startWeightKg: Double?
    var targetWeightKg: Double?
    var forecastEarliestWeek: Int?
    var forecastLatestWeek: Int?
    @Relationship(deleteRule: .cascade, inverse: \WorkoutDay.plan) var days: [WorkoutDay] = []

    init(id: UUID = UUID(), goalID: String, createdAt: Date = Date()) {
        self.id = id
        self.goalID = goalID
        self.createdAt = createdAt
    }
}
