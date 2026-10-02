import Foundation

/// One change to one workout of the plan. A workout is identified by its weekday and an exercise by its catalogue ID.
nonisolated enum WorkoutEdit: Equatable, Sendable {
    case removeExercise(weekday: Int, exerciseID: Exercise.ID)
    case moveExercise(weekday: Int, exerciseID: Exercise.ID, toIndex: Int)
    case setSets(weekday: Int, exerciseID: Exercise.ID, sets: Int)
    case addExercise(weekday: Int, exerciseID: Exercise.ID)
}

/// A new target weight for one exercise of one workout.
nonisolated struct TargetWeightChange: Equatable, Sendable {
    let weekday: Int
    let exerciseID: Exercise.ID
    let weightKg: Double
}

/// Applies one edit to a plan and returns the changed plan. Pure: nothing is loaded or saved here.
nonisolated struct WorkoutPlanEditor {
    let catalogue: [Exercise]
    var validator = WorkoutPlanValidator()

    func apply(_ edit: WorkoutEdit, to plan: WorkoutPlan, for user: UserPlanningProfile) throws(WorkoutPlanError)
        -> WorkoutPlan
    {
        let weekday = edit.weekday
        guard let workoutIndex = plan.workouts.firstIndex(where: { $0.weekday == weekday }) else {
            throw .workoutNotFound
        }
        let workout = plan.workouts[workoutIndex]
        var exercises = workout.exercises

        switch edit {
        case .removeExercise(_, let id):
            let index = try indexOf(id, in: exercises)
            guard exercises.count > 1 else { throw .cannotRemoveLastExercise }
            exercises.remove(at: index)

        case .moveExercise(_, let id, let toIndex):
            let index = try indexOf(id, in: exercises)
            guard exercises.indices.contains(toIndex) else { throw .invalidPosition }
            exercises.insert(exercises.remove(at: index), at: toIndex)

        case .setSets(_, let id, let sets):
            let index = try indexOf(id, in: exercises)
            guard (1...WorkoutExercise.maximumSets).contains(sets) else { throw .invalidSetCount }
            exercises[index].sets = sets
            try requireTime(for: exercises, user: user)

        case .addExercise(_, let id):
            guard let exercise = catalogue.first(where: { $0.id == id }) else { throw .exerciseNotFound }
            guard !exercises.contains(where: { $0.id == id }) else { throw .exerciseAlreadyInWorkout }
            guard workout.categoryIDs.contains(exercise.categoryID),
                  ExerciseEligibility.isAllowed(exercise, for: user)
            else { throw .exerciseNotAllowed }
            exercises.append(WorkoutExercise(exercise: exercise, sets: WorkoutExercise.baselineSets))
            try requireTime(for: exercises, user: user)
        }

        var workouts = plan.workouts
        workouts[workoutIndex] = PlannedWorkout(
            weekday: workout.weekday, categoryIDs: workout.categoryIDs, exercises: exercises)
        let edited = plan.replacingWorkouts(workouts)

        // Safety net: the edited plan must still pass every rule the planner's plans pass.
        do { try validator.validate(edited, for: user) } catch { throw .invalidPlan }
        return edited
    }

    /// Sets the target weights. They change neither the time nor the volume of a workout, so only the exercise and
    /// the weight are checked.
    func settingTargetWeights(_ changes: [TargetWeightChange], in plan: WorkoutPlan) throws(WorkoutPlanError)
        -> WorkoutPlan
    {
        var workouts = plan.workouts
        for change in changes {
            guard let workoutIndex = workouts.firstIndex(where: { $0.weekday == change.weekday }) else {
                throw .workoutNotFound
            }
            var exercises = workouts[workoutIndex].exercises
            let index = try indexOf(change.exerciseID, in: exercises)
            guard exercises[index].exercise.loadType != "bodyweight", change.weightKg.isFinite,
                  change.weightKg > 0, change.weightKg <= WorkoutSessionUseCase.maximumWeightKg
            else { throw .invalidWeight }
            exercises[index].targetWeightKg = change.weightKg
            workouts[workoutIndex] = PlannedWorkout(
                weekday: workouts[workoutIndex].weekday, categoryIDs: workouts[workoutIndex].categoryIDs,
                exercises: exercises)
        }
        return plan.replacingWorkouts(workouts)
    }

    private func indexOf(_ id: Exercise.ID, in exercises: [WorkoutExercise]) throws(WorkoutPlanError) -> Int {
        guard let index = exercises.firstIndex(where: { $0.id == id }) else { throw .exerciseNotFound }
        return index
    }

    private func requireTime(for exercises: [WorkoutExercise], user: UserPlanningProfile) throws(WorkoutPlanError) {
        guard exercises.reduce(0, { $0 + $1.seconds }) <= user.sessionMinutes * 60 else { throw .notEnoughTime }
    }
}

private extension WorkoutEdit {
    var weekday: Int {
        switch self {
        case .removeExercise(let weekday, _), .moveExercise(let weekday, _, _),
             .setSets(let weekday, _, _), .addExercise(let weekday, _):
            weekday
        }
    }
}
