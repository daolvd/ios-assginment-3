import Foundation
import Observation

@MainActor
@Observable
final class GeneratePlanViewModel {
    enum State {
        case idle
        case ready(WorkoutPlan)
        case failed(PlanningError)
    }

    private(set) var state = State.idle
    @ObservationIgnored private let createPlan: CreateWorkoutPlanUseCase

    init(createPlan: CreateWorkoutPlanUseCase) {
        self.createPlan = createPlan
    }

    /// Builds and stores a plan from the saved onboarding answers and the chosen goal.
    func generate(profile: OnboardingProfile, goalID: Goal.ID) {
        do {
            state = .ready(try createPlan.execute(for: UserPlanningProfile(profile: profile, goalID: goalID)))
        } catch {
            state = .failed(error)
        }
    }
}
