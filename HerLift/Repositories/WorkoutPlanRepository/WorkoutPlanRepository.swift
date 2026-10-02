import Foundation

/// Stores the single current plan. Saving replaces whatever was stored before.
@MainActor
protocol WorkoutPlanRepository {
    func loadPlan() throws -> WorkoutPlan?
    func savePlan(_ plan: WorkoutPlan) throws
    func deletePlan() throws
}
