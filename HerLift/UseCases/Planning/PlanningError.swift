import Foundation

nonisolated enum PlanningError: LocalizedError, Equatable {
    case unsupportedTrainingDays
    case unsupportedSessionMinutes
    case patternNotFound
    case emptyWorkout
    case invalidSessionCount
    case tooManyCategories
    case sessionTooLong
    case invalidExerciseCategory
    case invalidExerciseLevel
    case invalidSetCount

    var errorDescription: String? {
        switch self {
        case .unsupportedTrainingDays:
            "Choose between 1 and 7 different training days."
        case .unsupportedSessionMinutes:
            "Workouts can be between 20 and 120 minutes."
        case .patternNotFound, .emptyWorkout, .invalidSessionCount, .tooManyCategories,
             .sessionTooLong, .invalidExerciseCategory, .invalidExerciseLevel, .invalidSetCount:
            "We couldn't build your plan."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .unsupportedTrainingDays:
            "Pick your training days again."
        case .unsupportedSessionMinutes:
            "Pick a workout length in that range."
        case .patternNotFound, .emptyWorkout, .invalidSessionCount, .tooManyCategories,
             .sessionTooLong, .invalidExerciseCategory, .invalidExerciseLevel, .invalidSetCount:
            "Your answers are saved."
        }
    }
}
