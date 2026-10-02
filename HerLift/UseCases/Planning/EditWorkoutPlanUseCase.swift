import Foundation

/// Everything done with the current plan after it has been created: open it, change one workout, or delete it.
@MainActor
struct EditWorkoutPlanUseCase {
    let plans: any WorkoutPlanRepository
    let exercises: any ExerciseRepository

    /// The current plan, or nil when none has been created yet.
    func currentPlan() throws(WorkoutPlanError) -> WorkoutPlan? {
        do { return try plans.loadPlan() } catch { throw .couldNotLoadPlan }
    }

    /// Applies one edit to the current plan, checks the result and saves it.
    func execute(_ edit: WorkoutEdit, for user: UserPlanningProfile) throws(WorkoutPlanError) -> WorkoutPlan {
        guard let current = try currentPlan() else { throw .noPlan }

        let edited = try WorkoutPlanEditor(catalogue: exercises.exercises).apply(edit, to: current, for: user)
        do { try plans.savePlan(edited) } catch { throw .couldNotSavePlan }
        return edited
    }

    /// Deletes the current plan. Deleting when there is none is not an error.
    func deletePlan() throws(WorkoutPlanError) {
        do { try plans.deletePlan() } catch { throw .couldNotDeletePlan }
    }
}
