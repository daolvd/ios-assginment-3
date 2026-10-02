import Foundation

nonisolated enum WorkoutPlanError: LocalizedError, Equatable {
    case noPlan
    case invalidPlan
    case couldNotSavePlan
    case couldNotLoadPlan
    case couldNotDeletePlan
    case workoutNotFound
    case exerciseNotFound
    case exerciseAlreadyInWorkout
    case exerciseNotAllowed
    case cannotRemoveLastExercise
    case invalidSetCount
    case invalidPosition
    case notEnoughTime

    var errorDescription: String? {
        switch self {
        case .noPlan: "You don't have a plan yet."
        case .invalidPlan: "That plan isn't valid."
        case .couldNotSavePlan: "We couldn't save your plan."
        case .couldNotLoadPlan: "We couldn't open your plan."
        case .couldNotDeletePlan: "We couldn't delete your plan."
        case .workoutNotFound: "That workout isn't in your plan."
        case .exerciseNotFound: "That exercise isn't in this workout."
        case .exerciseAlreadyInWorkout: "That exercise is already in this workout."
        case .exerciseNotAllowed: "That exercise doesn't suit this workout."
        case .cannotRemoveLastExercise: "A workout needs at least one exercise."
        case .invalidSetCount: "Choose between 1 and 5 sets."
        case .invalidPosition: "That position isn't in this workout."
        case .notEnoughTime: "There isn't enough time left in this workout."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .noPlan: "Create your plan first."
        case .invalidPlan: "Change your answers and build your plan again."
        case .couldNotSavePlan, .couldNotLoadPlan, .couldNotDeletePlan: "Try again."
        case .workoutNotFound, .exerciseNotFound, .invalidPosition: "Go back to your plan and try again."
        case .exerciseAlreadyInWorkout, .exerciseNotAllowed: "Choose a different exercise."
        case .cannotRemoveLastExercise: "Add another exercise before removing this one."
        case .invalidSetCount: "Pick a number of sets in that range."
        case .notEnoughTime: "Remove an exercise or reduce the sets, then try again."
        }
    }
}
