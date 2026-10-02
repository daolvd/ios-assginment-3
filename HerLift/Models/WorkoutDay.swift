import Foundation
import SwiftData

@Model
nonisolated final class WorkoutDay {
    @Attribute(.unique) var id: UUID
    /// Position inside the plan; relationship arrays have no guaranteed order.
    var sortIndex: Int
    /// Monday = 1 … Sunday = 7.
    var weekday: Int
    var categoryIDs: [String]
    var plan: TrainingPlan?
    @Relationship(deleteRule: .cascade, inverse: \PlannedExercise.day) var exercises: [PlannedExercise] = []

    init(id: UUID = UUID(), sortIndex: Int, weekday: Int, categoryIDs: [String]) {
        self.id = id
        self.sortIndex = sortIndex
        self.weekday = weekday
        self.categoryIDs = categoryIDs
    }
}
