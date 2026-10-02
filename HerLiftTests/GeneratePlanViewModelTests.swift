import Foundation
import Testing
@testable import HerLift

@MainActor
struct GeneratePlanViewModelTests {
    @Test func generateBuildsAndStoresThePlanFromTheOnboardingAnswers() throws {
        let store = PlanStoreStub()
        let viewModel = try makeViewModel(store)

        viewModel.generate(profile: profile(), goalID: "buildMuscle")

        guard case .ready(let plan) = viewModel.state else { Issue.record("expected a plan"); return }
        #expect(plan.goalID == "buildMuscle")
        #expect(plan.workouts.map(\.weekday) == [1, 3, 6])
        #expect(store.plan == plan)
    }

    @Test func generateReportsWhyThePlanCouldNotBeBuiltAndStoresNothing() throws {
        let store = PlanStoreStub()
        let viewModel = try makeViewModel(store)

        viewModel.generate(profile: profile(note: "Back pain"), goalID: "buildMuscle")

        guard case .failed(let error) = viewModel.state else { Issue.record("expected a failure"); return }
        #expect(error == .medicalClearanceRequired)
        #expect(store.plan == nil)
    }

    private func makeViewModel(_ store: PlanStoreStub) throws -> GeneratePlanViewModel {
        GeneratePlanViewModel(createPlan: CreateWorkoutPlanUseCase(
            patterns: try JSONTrainingPatternRepository(), exercises: try JSONExerciseRepository(), plans: store))
    }

    private func profile(note: String? = nil) -> OnboardingProfile {
        OnboardingProfile(
            age: 29, heightCm: 165, weightKg: 62, experience: .beginner, trainingWeekdays: [1, 3, 6],
            sessionMinutes: 45, healthNote: note, clearedByDoctor: false)
    }
}
