import Foundation

/// One change to one workout of the plan. A workout is identified by its weekday and an exercise by its catalogue ID.
nonisolated enum WorkoutEdit: Equatable, Sendable {
    case removeExercise(weekday: Int, exerciseID: Exercise.ID)
    case moveExercise(weekday: Int, exerciseID: Exercise.ID, toIndex: Int)
    case setSets(weekday: Int, exerciseID: Exercise.ID, sets: Int)
    case addExercise(weekday: Int, exerciseID: Exercise.ID)
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
        let edited = WorkoutPlan(goalID: plan.goalID, workouts: workouts)

        // Safety net: the edited plan must still pass every rule the planner's plans pass.
        do { try validator.validate(edited, for: user) } catch { throw .invalidPlan }
        return edited
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
