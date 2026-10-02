import Foundation

/// Final safety net: checks a finished plan against the person's answers, independently of how it was built.
nonisolated struct WorkoutPlanValidator {
    /// A workout trains at most two main categories; core may be added on top of them.
    static let maxMainCategoriesPerWorkout = 2

    func validate(_ plan: WorkoutPlan, for user: UserPlanningProfile) throws(PlanningError) {
        guard plan.workouts.count == user.trainingDays.count else { throw .invalidSessionCount }

        for workout in plan.workouts {
            let mainCategories = workout.categoryIDs.filter { $0 != Category.coreID }
            guard mainCategories.count <= Self.maxMainCategoriesPerWorkout else { throw .tooManyCategories }
            guard !workout.exercises.isEmpty else { throw .emptyWorkout }
            guard workout.estimatedMinutes <= user.sessionMinutes else { throw .sessionTooLong }

            for planned in workout.exercises {
                guard (1...WorkoutExercise.maximumSets).contains(planned.sets) else { throw .invalidSetCount }
                guard workout.categoryIDs.contains(planned.exercise.categoryID) else {
                    throw .invalidExerciseCategory
                }
                guard let level = TrainingLevel(rawValue: planned.exercise.level), level <= user.level else {
                    throw .invalidExerciseLevel
                }
            }
        }
    }
}
