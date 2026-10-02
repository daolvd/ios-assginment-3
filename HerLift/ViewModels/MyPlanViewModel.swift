import Foundation
import Observation

/// The home screen's data: the stored plan laid out for the current week.
@MainActor
@Observable
final class MyPlanViewModel {
    private(set) var plan: WorkoutPlan?
    var error: WorkoutPlanError?
    let goals: [Goal]
    @ObservationIgnored private let editPlan: EditWorkoutPlanUseCase
    @ObservationIgnored let now: () -> Date

    init(editPlan: EditWorkoutPlanUseCase, goals: [Goal], now: @escaping () -> Date = { Date() }) {
        self.editPlan = editPlan
        self.goals = goals
        self.now = now
    }

    /// Reads the stored plan again; nil when none has been created.
    func load() {
        do {
            plan = try editPlan.currentPlan()
            error = nil
        } catch {
            self.error = error
        }
    }

    var week: PlanWeek? {
        plan.map { PlanWeek(plan: $0, today: now()) }
    }

    func goalTitle(for plan: WorkoutPlan) -> String {
        goals.first { $0.id == plan.goalID }?.title ?? plan.goalID
    }
}
