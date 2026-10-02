import Foundation
import Testing
@testable import HerLift

@MainActor
struct ProfileViewModelTests {
    @Test func refreshShowsTheSavedAnswersAndTheGoalOfTheStoredPlan() throws {
        let fixture = try makeFixture()

        fixture.viewModel.refresh()

        let input = fixture.viewModel.editor.input
        #expect(input.age == "29")
        #expect(input.height == "165.0")
        #expect(input.weight == "80.0")
        #expect(input.experience == .beginner)
        #expect(input.trainingDays == [1, 3, 6])
        #expect(input.minutes == 45)
        #expect(input.selectedGoalID == "loseFat")
        #expect(input.targetWeight == "56")
        #expect(!fixture.viewModel.hasUnsavedChanges)
    }

    @Test func theSummariesReadTheAnswersInPlainWords() throws {
        let fixture = try makeFixture()
        fixture.viewModel.refresh()

        #expect(fixture.viewModel.aboutSummary == "29 · 165 cm · 80 kg · Beginner")
        #expect(fixture.viewModel.trainingSummary == "Mon, Wed, Sat · 45 min")
        #expect(fixture.viewModel.goalSummary == "Lose fat · 56 kg")

        fixture.viewModel.editor.input.selectedGoalID = "buildMuscle"
        #expect(fixture.viewModel.goalSummary == "Build muscle")
        fixture.viewModel.editor.input.selectedGoalID = nil
        #expect(fixture.viewModel.goalSummary == "Not chosen")
    }

    @Test func changingAnAnswerAllowsRebuildingOnlyWhileTheGoalStaysValid() throws {
        let fixture = try makeFixture()
        fixture.viewModel.refresh()
        #expect(!fixture.viewModel.canRebuild)

        fixture.viewModel.editor.input.minutes = 60
        #expect(fixture.viewModel.hasUnsavedChanges)
        #expect(fixture.viewModel.canRebuild)

        fixture.viewModel.editor.input.targetWeight = "45" // below a healthy weight at 165 cm
        #expect(!fixture.viewModel.canRebuild)
    }

    @Test func refreshKeepsChangesThatWereNotApplied() throws {
        let fixture = try makeFixture()
        fixture.viewModel.refresh()
        fixture.viewModel.editor.input.minutes = 60

        fixture.viewModel.refresh()

        #expect(fixture.viewModel.editor.input.minutes == 60)
    }

    @Test func rebuildSavesTheAnswersAndStoresANewDraftPlan() throws {
        let fixture = try makeFixture()
        fixture.viewModel.refresh()
        fixture.viewModel.editor.input.minutes = 60
        fixture.viewModel.editor.input.selectedGoalID = "buildMuscle"

        #expect(fixture.viewModel.rebuild(using: fixture.generatePlan))

        #expect(fixture.profiles.saved?.sessionMinutes == 60)
        #expect(fixture.store.plan?.goalID == "buildMuscle")
        #expect(fixture.store.plan?.status == .draft)
        guard case .ready(let plan) = fixture.generatePlan.state else { Issue.record("expected the new plan"); return }
        #expect(plan == fixture.store.plan)
        #expect(!fixture.viewModel.hasUnsavedChanges)
        #expect(fixture.viewModel.planningError == nil)
    }

    @Test func aPlanThatCannotBeBuiltLeavesTheStoredPlanAndSaysWhy() throws {
        let fixture = try makeFixture()
        fixture.viewModel.refresh()
        fixture.viewModel.editor.input.healthNote = "Knee pain" // without a doctor's clearance

        #expect(!fixture.viewModel.rebuild(using: fixture.generatePlan))

        #expect(fixture.viewModel.planningError == .medicalClearanceRequired)
        #expect(fixture.store.plan == storedPlan())
    }

    @Test func invalidAnswersAreReportedAndNothingChanges() throws {
        let fixture = try makeFixture()
        fixture.viewModel.refresh()
        fixture.viewModel.editor.input.age = ""

        #expect(!fixture.viewModel.rebuild(using: fixture.generatePlan))

        #expect(fixture.viewModel.editor.error == .invalidAge)
        #expect(fixture.viewModel.planningError == nil)
        #expect(fixture.store.plan == storedPlan())
    }

    // MARK: Fixtures

    private struct Fixture {
        let viewModel: ProfileViewModel
        let generatePlan: GeneratePlanViewModel
        let store: PlanStoreStub
        let profiles: ProfileStoreStub
    }

    private func makeFixture() throws -> Fixture {
        let store = PlanStoreStub(plan: storedPlan())
        let profiles = ProfileStoreStub(saved: OnboardingProfile(
            age: 29, heightCm: 165, weightKg: 80, experience: .beginner, trainingWeekdays: [1, 3, 6],
            sessionMinutes: 45, healthNote: nil, clearedByDoctor: false))
        let exercises = try JSONExerciseRepository()
        let editPlan = EditWorkoutPlanUseCase(plans: store, exercises: exercises)
        let editor = OnboardingViewModel(
            goals: onboardingPreviewGoals, saveProfile: SaveOnboardingProfileUseCase(repository: profiles))
        let viewModel = ProfileViewModel(
            editor: editor, loadProfile: LoadOnboardingProfileUseCase(repository: profiles), editPlan: editPlan)
        let generatePlan = GeneratePlanViewModel(
            createPlan: CreateWorkoutPlanUseCase(
                patterns: try JSONTrainingPatternRepository(), exercises: exercises, plans: store),
            editPlan: editPlan, goals: onboardingPreviewGoals)
        return Fixture(viewModel: viewModel, generatePlan: generatePlan, store: store, profiles: profiles)
    }

    /// An accepted fat-loss plan aiming for 56 kg.
    private func storedPlan() -> WorkoutPlan {
        WorkoutPlan(
            goalID: "loseFat", workouts: [], status: .active,
            weightForecast: WeightLossForecast(currentKg: 80, targetKg: 56, earliestWeek: 24, latestWeek: 48),
            startedOn: Date(timeIntervalSince1970: 1_790_000_000))
    }
}

@MainActor
private final class ProfileStoreStub: OnboardingProfileRepository {
    var saved: OnboardingProfile?
    init(saved: OnboardingProfile?) { self.saved = saved }

    func loadOnboardingProfile() throws -> OnboardingProfile? { saved }
    func saveOnboardingProfile(_ profile: OnboardingProfile) throws { saved = profile }
}
