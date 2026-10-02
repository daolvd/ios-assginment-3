import Foundation

/// A week of workouts. It lives in memory only; nothing here is persisted.
nonisolated struct WorkoutPlan: Equatable, Sendable {
    let goalID: Goal.ID
    /// One workout per training day, in weekday order.
    let workouts: [PlannedWorkout]
}

nonisolated struct PlannedWorkout: Equatable, Identifiable, Sendable {
    /// Monday = 1 … Sunday = 7.
    let weekday: Int
    let categoryIDs: [Category.ID]
    let exercises: [WorkoutExercise]

    var id: Int { weekday }

    /// Total time of all sets including rests, rounded up to whole minutes.
    var estimatedMinutes: Int { (exercises.reduce(0) { $0 + $1.seconds } + 59) / 60 }
}

/// One catalogue exercise with the number of sets planned for it.
nonisolated struct WorkoutExercise: Equatable, Identifiable, Sendable {
    static let baselineSets = 3
    static let maximumSets = 5

    let exercise: Exercise
    var sets: Int

    var id: Exercise.ID { exercise.id }

    /// The catalogue's estimated minutes cover the baseline sets with their rests,
    /// so one more set costs a baseline share of that time.
    var secondsPerSet: Int { exercise.estimatedMinutes * 60 / Self.baselineSets }
    var seconds: Int { secondsPerSet * sets }
}

nonisolated extension Category {
    static let coreID = "core"
}
