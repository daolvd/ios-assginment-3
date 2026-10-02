import Foundation
import SwiftData

@Model
nonisolated final class PlannedExercise {
    @Attribute(.unique) var id: UUID
    /// Position inside the workout; relationship arrays have no guaranteed order.
    var sortIndex: Int
    /// Catalogue exercise ID. The exercise itself is never copied into the store.
    var exerciseID: String
    var sets: Int
    var day: WorkoutDay?

    init(id: UUID = UUID(), sortIndex: Int, exerciseID: String, sets: Int) {
        self.id = id
        self.sortIndex = sortIndex
        self.exerciseID = exerciseID
        self.sets = sets
    }
}
