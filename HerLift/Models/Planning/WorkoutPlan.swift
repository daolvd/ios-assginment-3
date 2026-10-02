import Foundation

nonisolated enum PlanStatus: String, Sendable {
    /// Built and stored, waiting for her to accept it.
    case draft
    case active
}

/// A week of workouts with the forecast for its goal.
nonisolated struct WorkoutPlan: Equatable, Sendable {
    let goalID: Goal.ID
    /// One workout per training day, in weekday order.
    let workouts: [PlannedWorkout]
    var status: PlanStatus = .draft
    /// Only for the fat-loss goal; other goals only have milestones.
    var weightForecast: WeightLossForecast?
    /// Start of the day she accepted the plan. Plan weeks count from here.
    var startedOn: Date?

    var milestones: [ForecastMilestone] { ForecastCalculator.milestones(for: goalID) }

    func replacingWorkouts(_ workouts: [PlannedWorkout]) -> WorkoutPlan {
        WorkoutPlan(goalID: goalID, workouts: workouts, status: status,
                    weightForecast: weightForecast, startedOn: startedOn)
    }
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
