import Foundation
import Testing
@testable import HerLift

@MainActor
struct PlanGenerationTests {
    @Test func unsafeLoseFatTargetBlocksBuildAndNeverCallsGenerator() async {
        let stub = PlanGeneratorStub()
        let viewModel = makeViewModel(stub: stub)
        viewModel.input.selectedGoalID = "loseFat"
        viewModel.input.targetWeight = "45"  // BMI 16.5 at 165 cm — below 18.5

        #expect(!viewModel.canBuildPlan)
        #expect(viewModel.targetWeightError == .unsafeTargetWeight)
        await viewModel.buildPlan()

        #expect(viewModel.generationPhase == .editing)
        #expect(viewModel.plan == nil)
        #expect(stub.calls == 0)
    }

    @Test func buildPlanRunsUseCaseAndBecomesReadyWithPlanAndPlannerLabel() async throws {
        let stub = PlanGeneratorStub()
        let viewModel = makeViewModel(stub: stub)
        viewModel.input.selectedGoalID = "buildStrength"

        await viewModel.buildPlan()

        #expect(viewModel.generationPhase == .ready)
        #expect(viewModel.generationError == nil)
        #expect(viewModel.plan === stub.lastPlan)
        #expect(viewModel.plan?.goalRaw == "buildStrength")
        #expect(viewModel.plan?.statusRaw == "draft")
        #expect(viewModel.plannerLabel == "HerLift rules")
        let request = try #require(stub.lastRequest)
        #expect(request.goalID == "buildStrength")
        #expect(request.trainingWeekdays == [1, 3, 6])
        #expect(request.sessionMinutes == 45)
        #expect(request.age == 29)
        #expect(request.heightCm == 165)
        #expect(request.weightKg == 62)
        #expect(request.targetWeightKg == nil)
        #expect(request.clearedByDoctor == false)
    }

    @Test func loseFatTargetRidesIntoTheRequest() async throws {
        let stub = PlanGeneratorStub()
        let viewModel = makeViewModel(stub: stub)
        viewModel.input.selectedGoalID = "loseFat"
        viewModel.input.targetWeight = "58"

        await viewModel.buildPlan()

        #expect(viewModel.generationPhase == .ready)
        #expect(try #require(stub.lastRequest).targetWeightKg == 58)
    }

    @Test func healthNoteWithoutClearanceFailsInUseCaseAndStaysEditable() async {
        let stub = PlanGeneratorStub()
        let viewModel = makeViewModel(stub: stub)
        viewModel.input.selectedGoalID = "buildStrength"
        viewModel.input.healthNote = "Knee injury"
        viewModel.input.clearedByDoctor = false

        await viewModel.buildPlan()

        #expect(viewModel.generationPhase == .editing)
        #expect(viewModel.generationError == .medicalClearanceRequired)
        #expect(viewModel.plan == nil)
        #expect(stub.calls == 0)
    }

    @Test func healthNoteWithClearanceBuildsNormally() async {
        let stub = PlanGeneratorStub()
        let viewModel = makeViewModel(stub: stub)
        viewModel.input.selectedGoalID = "buildStrength"
        viewModel.input.healthNote = "Knee injury"
        viewModel.input.clearedByDoctor = true

        await viewModel.buildPlan()

        #expect(viewModel.generationPhase == .ready)
        #expect(stub.calls == 1)
        #expect(stub.lastRequest?.clearedByDoctor == true)
    }

    @Test func missingGoalIsReportedByUseCaseWithoutCallingGenerator() async {
        let stub = PlanGeneratorStub()
        let useCase = CreatePersonalisedPlanUseCase(generator: stub)
        // The ViewModel no-ops while no goal is selected (Build stays disabled);
        // UC1 still owns the rule for any caller that slips through.
        await #expect(throws: CreatePersonalisedPlanError.missingGoal) {
            try await useCase.execute(PlanRequest(
                experience: .beginner, goalID: "", targetWeightKg: nil,
                trainingWeekdays: [1, 3, 6], sessionMinutes: 45,
                age: 29, heightCm: 165, weightKg: 62, healthNote: nil, clearedByDoctor: false
            ))
        }
        #expect(stub.calls == 0)
    }

    @Test func invalidRequestNeverReachesTheGenerator() async {
        let stub = PlanGeneratorStub()
        let useCase = CreatePersonalisedPlanUseCase(generator: stub)

        await #expect(throws: CreatePersonalisedPlanError.unsupportedTrainingFrequency) {
            try await useCase.execute(PlanRequest(
                experience: .beginner, goalID: "buildStrength", targetWeightKg: nil,
                trainingWeekdays: [1], sessionMinutes: 45,
                age: 29, heightCm: 165, weightKg: 62, healthNote: nil, clearedByDoctor: false
            ))
        }
        await #expect(throws: CreatePersonalisedPlanError.invalidSessionDuration) {
            try await useCase.execute(PlanRequest(
                experience: .beginner, goalID: "buildStrength", targetWeightKg: nil,
                trainingWeekdays: [1, 3, 6], sessionMinutes: 33,
                age: 29, heightCm: 165, weightKg: 62, healthNote: nil, clearedByDoctor: false
            ))
        }
        #expect(stub.calls == 0)
    }

    @Test func failedBuildCanRetryAndRecover() async {
        let stub = PlanGeneratorStub(failures: 1)
        let viewModel = makeViewModel(stub: stub)
        viewModel.input.selectedGoalID = "buildStrength"

        await viewModel.buildPlan()
        #expect(viewModel.generationPhase == .failed)
        #expect(viewModel.generationError == .noSuitableExercises)
        #expect(viewModel.plan == nil)

        await viewModel.retryBuildPlan()
        #expect(viewModel.generationPhase == .ready)
        #expect(viewModel.generationError == nil)
        #expect(viewModel.plan === stub.lastPlan)
        #expect(stub.calls == 2)
    }

    @Test func changeAnswersDiscardsPlanButKeepsAnswers() async {
        let stub = PlanGeneratorStub()
        let viewModel = makeViewModel(stub: stub)
        viewModel.input.selectedGoalID = "buildStrength"
        await viewModel.buildPlan()
        #expect(viewModel.generationPhase == .ready)

        viewModel.changeAnswers()

        #expect(viewModel.generationPhase == .editing)
        #expect(viewModel.plan == nil)
        #expect(viewModel.plannerLabel == nil)
        #expect(viewModel.generationError == nil)
        #expect(viewModel.input.weight == "62")
        #expect(viewModel.input.selectedGoalID == "buildStrength")
    }

    @Test func planRulesBodyMetrics() {
        guard let bmi = PlanRules.bmi(weightKg: 62, heightCm: 165) else {
            Issue.record("BMI should be computable for positive metrics")
            return
        }
        #expect(abs(bmi - 22.7732) < 0.0001)
        #expect(PlanRules.bmi(weightKg: 0, heightCm: 165) == nil)
        #expect(PlanRules.bmi(weightKg: 62, heightCm: .nan) == nil)
        // The unsafe-target boundary: 50 kg at 165 cm is BMI 18.37, 50.5 kg is 18.55.
        #expect(!PlanRules.isSafeTargetWeight(50, heightCm: 165))
        #expect(PlanRules.isSafeTargetWeight(50.5, heightCm: 165))
    }

    // MARK: - Fixtures

    /// Builds a minimal TrainingPlan from whatever request arrives; the first
    /// `failures` calls throw `noSuitableExercises` so tests can drive retry.
    private final class PlanGeneratorStub: PlanGenerating, @unchecked Sendable {
        let kind = PlanGeneratorKind.ruleBased
        nonisolated(unsafe) private(set) var calls = 0
        nonisolated(unsafe) private(set) var lastRequest: PlanRequest?
        nonisolated(unsafe) private(set) var lastPlan: TrainingPlan?
        private let failures: Int

        init(failures: Int = 0) {
            self.failures = failures
        }

        func generate(_ request: PlanRequest) async throws(CreatePersonalisedPlanError) -> TrainingPlan {
            calls += 1
            lastRequest = request
            if calls <= failures { throw .noSuitableExercises }
            let profile = UserProfile(
                age: request.age, heightCm: request.heightCm, weightKg: request.weightKg,
                experienceRaw: request.experience.rawValue,
                trainingWeekdays: request.trainingWeekdays, sessionMinutes: request.sessionMinutes,
                healthNote: request.healthNote, clearedByDoctor: request.clearedByDoctor
            )
            let plan = TrainingPlan(
                profile: profile, statusRaw: "draft", goalRaw: request.goalID,
                targetWeightKg: request.targetWeightKg, strategyRaw: "standard",
                generatorRaw: kind.rawValue, coachText: "Three days a week — let's build the habit."
            )
            lastPlan = plan
            return plan
        }
    }

    private func makeViewModel(stub: PlanGeneratorStub) -> OnboardingViewModel {
        var input = OnboardingInput()
        input.age = "29"
        input.height = "165"
        input.weight = "62"
        return OnboardingViewModel(
            goals: [
                Goal(id: "loseFat", title: "Lose fat", requiresTargetWeight: true),
                Goal(id: "buildStrength", title: "Get stronger", requiresTargetWeight: false),
            ],
            input: input,
            saveProfile: SaveOnboardingProfileUseCase(repository: ProfileRepositoryStub()),
            createPlan: CreatePersonalisedPlanUseCase(generator: stub)
        )
    }
}

@MainActor
private final class ProfileRepositoryStub: OnboardingProfileRepository {
    var saved: OnboardingProfile?
    var fails = false

    func loadOnboardingProfile() throws -> OnboardingProfile? { saved }

    func saveOnboardingProfile(_ profile: OnboardingProfile) throws {
        if fails { throw CocoaError(.fileWriteUnknown) }
        saved = profile
    }
}
