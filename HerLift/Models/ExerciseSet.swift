import Foundation
import SwiftData

@Model
nonisolated final class ExerciseSet {
    @Attribute(.unique) var id: UUID
    /// Position inside the session; relationship arrays have no guaranteed order.
    var sortIndex: Int
    /// Catalogue exercise ID.
    var exerciseID: String
    var setNumber: Int
    var weightKg: Double
    var repetitions: Int
    var effortRaw: String
    var session: WorkoutSession?

    init(
        id: UUID = UUID(), sortIndex: Int, exerciseID: String, setNumber: Int,
        weightKg: Double, repetitions: Int, effortRaw: String
    ) {
        self.id = id
        self.sortIndex = sortIndex
        self.exerciseID = exerciseID
        self.setNumber = setNumber
        self.weightKg = weightKg
        self.repetitions = repetitions
        self.effortRaw = effortRaw
    }
}
