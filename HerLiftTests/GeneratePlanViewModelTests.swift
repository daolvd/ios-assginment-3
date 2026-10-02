import Foundation
import Testing
@testable import HerLift

@MainActor
struct GeneratePlanViewModelTests {
    @Test func generateBuildsAndStoresThePlanFromTheOnboardingAnswers() throws {
        let store = PlanStoreStub()
        let viewModel = try makeViewModel(store)

        viewModel.generate(profile: profile(), goalID: "buildMuscle", targetWeightKg: nil)

        guard case .ready(let plan) = viewModel.state else { Issue.record("expected a plan"); return }
        #expect(plan.goalID == "buildMuscle")
        #expect(plan.workouts.map(\.weekday) == [1, 3, 6])
        #expect(store.plan == plan)
    }

    @Test func generateReportsWhyThePlanCouldNotBeBuiltAndStoresNothing() throws {
        let store = PlanStoreStub()
        let viewModel = try makeViewModel(store)

        viewModel.generate(profile: profile(note: "Back pain"), goalID: "buildMuscle", targetWeightKg: nil)

        guard case .failed(let error) = viewModel.state else { Issue.record("expected a failure"); return }
        #expect(error == .medicalClearanceRequired)
        #expect(store.plan == nil)
    }

    @Test func acceptActivatesTheStoredPlan() throws {
        let store = PlanStoreStub()
        let viewModel = try makeViewModel(store)
        viewModel.generate(profile: profile(), goalID: "buildMuscle", targetWeightKg: nil)

        viewModel.accept()

        guard case .ready(let plan) = viewModel.state else { Issue.record("expected a plan"); return }
        #expect(plan.status == .active)
        #expect(store.plan?.status == .active)
        #expect(viewModel.error == nil)
    }

    @Test func acceptingTwiceReportsThatThePlanIsAlreadyActive() throws {
        let viewModel = try makeViewModel(PlanStoreStub())
        viewModel.generate(profile: profile(), goalID: "buildMuscle", targetWeightKg: nil)
        viewModel.accept()

        viewModel.accept()

        #expect(viewModel.error == .planAlreadyAccepted)
    }

    @Test func startOverDeletesThePlanAndReportsFailures() throws {
        let store = PlanStoreStub()
        let viewModel = try makeViewModel(store)
        viewModel.generate(profile: profile(), goalID: "buildMuscle", targetWeightKg: nil)

        #expect(viewModel.startOver())
        #expect(store.plan == nil)

        store.fails = true
        #expect(!viewModel.startOver())
        #expect(viewModel.error == .couldNotDeletePlan)
    }

    @Test func goalTitleComesFromTheGoalList() throws {
        let viewModel = try makeViewModel(PlanStoreStub())
        #expect(viewModel.goalTitle(for: WorkoutPlan(goalID: "buildMuscle", workouts: [])) == "Build muscle")
        #expect(viewModel.goalTitle(for: WorkoutPlan(goalID: "other", workouts: [])) == "other")
    }

    private func makeViewModel(_ store: PlanStoreStub) throws -> GeneratePlanViewModel {
        let exercises = try JSONExerciseRepository()
        return GeneratePlanViewModel(
            createPlan: CreateWorkoutPlanUseCase(
                patterns: try JSONTrainingPatternRepository(), exercises: exercises, plans: store),
            editPlan: EditWorkoutPlanUseCase(plans: store, exercises: exercises),
            goals: [Goal(id: "buildMuscle", title: "Build muscle", requiresTargetWeight: false)])
    }

    private func profile(note: String? = nil) -> OnboardingProfile {
        OnboardingProfile(
            age: 29, heightCm: 165, weightKg: 62, experience: .beginner, trainingWeekdays: [1, 3, 6],
            sessionMinutes: 45, healthNote: note, clearedByDoctor: false)
    }
}
