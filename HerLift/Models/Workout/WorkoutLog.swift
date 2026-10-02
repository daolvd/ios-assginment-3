import Foundation

nonisolated enum PerceivedEffort: String, CaseIterable, Sendable {
    case easy, good, hard, tooHard

    var title: String {
        switch self {
        case .easy: "Easy"
        case .good: "Good"
        case .hard: "Hard"
        case .tooHard: "Too hard"
        }
    }
}

/// One finished set: what she lifted and how it felt.
nonisolated struct LoggedSet: Equatable, Sendable {
    let exerciseID: Exercise.ID
    /// Counted from 1 inside its exercise.
    let setNumber: Int
    /// 0 for bodyweight exercises.
    let weightKg: Double
    let repetitions: Int
    let effort: PerceivedEffort
}

nonisolated enum WorkoutStatus: String, Sendable {
    case inProgress
    case completed
}

/// What happened in one day's workout, from starting it to finishing it.
nonisolated struct WorkoutLog: Equatable, Sendable {
    /// The start of the day it was done.
    let date: Date
    /// Monday = 1 … Sunday = 7.
    let weekday: Int
    var status: WorkoutStatus
    /// In the order they were done.
    var sets: [LoggedSet]
}

/// The set she is on: which exercise of the workout and which set of it.
nonisolated struct WorkoutStep: Equatable, Sendable {
    let exerciseIndex: Int
    let setNumber: Int
}

nonisolated extension PlannedWorkout {
    /// The first planned set that has not been logged yet, going exercise by exercise; nil when every set is done.
    func nextStep(after log: WorkoutLog) -> WorkoutStep? {
        for (index, planned) in exercises.enumerated() {
            for setNumber in stride(from: 1, through: planned.sets, by: 1)
            where !log.sets.contains(where: { $0.exerciseID == planned.id && $0.setNumber == setNumber }) {
                return WorkoutStep(exerciseIndex: index, setNumber: setNumber)
            }
        }
        return nil
    }
}
