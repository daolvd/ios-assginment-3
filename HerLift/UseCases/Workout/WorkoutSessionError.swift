import Foundation

nonisolated enum WorkoutSessionError: LocalizedError, Equatable {
    case workoutNotActive
    case notToday
    case alreadyCompleted
    case exerciseNotInWorkout
    case invalidRepetitionCount
    case invalidWeight
    case duplicateSet
    case allSetsCompleted
    case nothingLogged
    case couldNotStartWorkout
    case couldNotSaveSet
    case couldNotFinishWorkout
    case couldNotLoadWorkouts
    case couldNotUpdatePlan

    var errorDescription: String? {
        switch self {
        case .workoutNotActive: "This workout isn't in progress."
        case .notToday: "You can only start today's workout."
        case .alreadyCompleted: "You've already finished today's workout."
        case .exerciseNotInWorkout: "This exercise isn't part of today's workout."
        case .invalidRepetitionCount: "A set needs at least one repetition."
        case .invalidWeight: "That weight doesn't look right for this exercise."
        case .duplicateSet: "You've already logged this set."
        case .allSetsCompleted: "You've finished every set for this exercise."
        case .nothingLogged: "You haven't logged a set yet."
        case .couldNotStartWorkout: "We couldn't start your workout."
        case .couldNotSaveSet: "We couldn't save your set."
        case .couldNotFinishWorkout: "We couldn't finish your workout."
        case .couldNotLoadWorkouts: "We couldn't open your workouts."
        case .couldNotUpdatePlan: "We couldn't update your plan."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .workoutNotActive: "Start today's workout before logging sets."
        case .notToday: "Open the workout on its own day."
        case .alreadyCompleted: "Come back on your next training day."
        case .exerciseNotInWorkout: "Go back to today's workout and choose the next exercise."
        case .invalidRepetitionCount: "Enter how many reps you completed, then tap Complete Set."
        case .invalidWeight: "Enter the weight shown on the machine or dumbbell."
        case .duplicateSet: "Move on to your next set."
        case .allSetsCompleted: "Move on to the next exercise."
        case .nothingLogged: "Log at least one set before finishing."
        case .couldNotStartWorkout, .couldNotFinishWorkout, .couldNotLoadWorkouts: "Try again."
        case .couldNotSaveSet: "Your workout is still open — tap Complete Set again."
        case .couldNotUpdatePlan: "Your plan hasn't changed — tap Apply again."
        }
    }
}
