import Foundation

nonisolated enum PlanningError: LocalizedError, Equatable {
    case unsupportedTrainingDays
    case unsupportedSessionMinutes
    case medicalClearanceRequired
    case patternNotFound
    case emptyWorkout
    case invalidSessionCount
    case tooManyCategories
    case sessionTooLong
    case invalidExerciseCategory
    case invalidExerciseLevel
    case invalidSetCount
    case couldNotSavePlan
    case targetWeightRequired
    case targetNotBelowCurrent
    case unsafeTargetWeight(minimumKg: Int)

    var errorDescription: String? {
        switch self {
        case .unsupportedTrainingDays:
            "Choose between 2 and 7 different training days."
        case .unsupportedSessionMinutes:
            "Workouts can be between 20 and 120 minutes."
        case .medicalClearanceRequired:
            "Please check with your doctor before you start."
        case .couldNotSavePlan:
            "We couldn't save your plan."
        case .targetWeightRequired:
            "Enter a target weight."
        case .targetNotBelowCurrent:
            "Your target is not below your current weight."
        case .unsafeTargetWeight:
            "This target is below a healthy weight for your height."
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
        case .medicalClearanceRequired:
            "Once a doctor has cleared you to exercise, turn on that answer and build your plan again."
        case .couldNotSavePlan:
            "Try again."
        case .targetWeightRequired:
            "Add the weight you would like to reach."
        case .targetNotBelowCurrent:
            "Choose a target below your current weight."
        case .unsafeTargetWeight(let minimumKg):
            "Choose \(minimumKg) kg or more."
        case .patternNotFound, .emptyWorkout, .invalidSessionCount, .tooManyCategories,
             .sessionTooLong, .invalidExerciseCategory, .invalidExerciseLevel, .invalidSetCount:
            "Your answers are saved."
        }
    }
}
