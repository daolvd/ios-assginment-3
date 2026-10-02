import Foundation

/// Everything done with the current plan after it has been created: open it, accept it, change one workout,
/// or delete it (start over).
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

    /// Sets the target weights of exercises, for example the starting weights a first workout shows or the
    /// weights she applies after a workout.
    func setTargetWeights(_ changes: [TargetWeightChange]) throws(WorkoutPlanError) -> WorkoutPlan {
        guard let current = try currentPlan() else { throw .noPlan }
        let updated = try WorkoutPlanEditor(catalogue: exercises.exercises).settingTargetWeights(changes, in: current)
        do { try plans.savePlan(updated) } catch { throw .couldNotSavePlan }
        return updated
    }

    /// Makes the draft plan the active plan, counting its weeks from the start of `now`'s day.
    func acceptPlan(now: Date = Date()) throws(WorkoutPlanError) -> WorkoutPlan {
        guard var plan = try currentPlan() else { throw .noPlan }
        guard plan.status == .draft else { throw .planAlreadyAccepted }

        plan.status = .active
        plan.startedOn = Calendar.current.startOfDay(for: now)
        do { try plans.savePlan(plan) } catch { throw .couldNotAcceptPlan }
        return plan
    }

    /// Deletes the current plan. Deleting when there is none is not an error.
    func deletePlan() throws(WorkoutPlanError) {
        do { try plans.deletePlan() } catch { throw .couldNotDeletePlan }
    }
}
