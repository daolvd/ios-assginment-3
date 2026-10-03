import Foundation

/// A plan store that tells the backup after every change to the plan: a new plan, an accepted plan, new target
/// weights from feedback, a deleted plan. Every way the plan can change goes through here, so none is missed.
@MainActor
final class BackingUpWorkoutPlanRepository: WorkoutPlanRepository {
    private let base: any WorkoutPlanRepository
    private let planChanged: @MainActor () -> Void

    init(_ base: any WorkoutPlanRepository, planChanged: @escaping @MainActor () -> Void) {
        self.base = base
        self.planChanged = planChanged
    }

    func loadPlan() throws -> WorkoutPlan? { try base.loadPlan() }

    func savePlan(_ plan: WorkoutPlan) throws {
        try base.savePlan(plan)
        planChanged()
    }

    func deletePlan() throws {
        try base.deletePlan()
        planChanged()
    }
}
