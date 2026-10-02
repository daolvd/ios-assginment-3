import Foundation

/// Which catalogue exercises a person may be given: their level and their hard constraints, nothing else.
nonisolated enum ExerciseEligibility {
    static let floorBasedTagID = "floor-based"
    static let lowImpactTagID = "low-impact"

    static func isAllowed(_ exercise: Exercise, for user: UserPlanningProfile) -> Bool {
        guard let level = TrainingLevel(rawValue: exercise.level), level <= user.level else { return false }
        if user.mustAvoidFloorExercises, exercise.tagIDs.contains(floorBasedTagID) { return false }
        if user.requiresLowImpact, !exercise.tagIDs.contains(lowImpactTagID) { return false }
        return true
    }
}
