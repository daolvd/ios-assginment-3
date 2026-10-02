import Foundation
import Observation

/// Builds the plan after onboarding and handles what she does with it: accept it or start over.
@MainActor
@Observable
final class GeneratePlanViewModel {
    enum State {
        case idle
        case ready(WorkoutPlan)
        case failed(PlanningError)
    }

    private(set) var state = State.idle
    /// Why accepting or starting over did not work; shown as an alert.
    var error: WorkoutPlanError?
    let goals: [Goal]
    @ObservationIgnored private let createPlan: CreateWorkoutPlanUseCase
    @ObservationIgnored private let editPlan: EditWorkoutPlanUseCase

    init(createPlan: CreateWorkoutPlanUseCase, editPlan: EditWorkoutPlanUseCase, goals: [Goal]) {
        self.createPlan = createPlan
        self.editPlan = editPlan
        self.goals = goals
    }

    /// Builds and stores a plan from the saved onboarding answers and the chosen goal.
    func generate(profile: OnboardingProfile, goalID: Goal.ID, targetWeightKg: Double?) {
        do {
            let user = UserPlanningProfile(profile: profile, goalID: goalID, targetWeightKg: targetWeightKg)
            state = .ready(try createPlan.execute(for: user))
        } catch {
            state = .failed(error)
        }
    }

    /// Shows the stored plan again if she left before accepting it. An accepted plan belongs to My Plan instead.
    func restore() {
        guard let stored = try? editPlan.currentPlan(), stored.status == .draft else { return }
        state = .ready(stored)
    }

    /// Returns true when the plan is now active.
    @discardableResult
    func accept() -> Bool {
        do {
            state = .ready(try editPlan.acceptPlan())
            error = nil
            return true
        } catch {
            self.error = error
            return false
        }
    }

    /// Deletes the plan so she can answer again. Returns false when it could not be deleted.
    func startOver() -> Bool {
        do {
            try editPlan.deletePlan()
            error = nil
            return true
        } catch {
            self.error = error
            return false
        }
    }

    func goalTitle(for plan: WorkoutPlan) -> String {
        goals.first { $0.id == plan.goalID }?.title ?? plan.goalID
    }
}
