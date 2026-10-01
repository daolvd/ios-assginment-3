import Foundation
import Testing
import SwiftData
@testable import HerLift

@MainActor
struct PlanGenerationTests {
    @Test func aiIntegrationRetriesInvalidScheduleAndReportsTheAcceptedSource() async throws {
        let catalogue = try JSONExerciseRepository().exercises
        let request = integrationRequest()
        let valid = try PlanRuleEngine().generate(request, catalogue: catalogue)
        valid.generatorRaw = "onDeviceAI"
        let ai = IntegrationGeneratorStub(kind: .onDeviceAI, plan: valid, invalidResponses: 1)
        let fallback = IntegrationGeneratorStub(kind: .ruleBased, plan: valid)
        let useCase = CreatePersonalisedPlanUseCase(generator: ai, catalogue: catalogue, fallback: fallback)
        let plan = try await useCase.execute(request)
        #expect(plan === valid)
        #expect(ai.calls == 2)
        #expect(ai.feedback == [nil, .invalidTrainingPlan])
        #expect(fallback.calls == 0)
        #expect(plan.generatorRaw == "onDeviceAI")

        let schema = Schema([UserProfile.self, TrainingPlan.self, WorkoutDay.self,
                             PlannedExercise.self, WorkoutSession.self, ExerciseSet.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let profiles = try SwiftDataUserProfileRepository(modelContext: context)
        let plans = try SwiftDataTrainingPlanRepository(modelContext: context)
        let unavailable = IntegrationGeneratorStub(kind: .onDeviceAI, plan: valid, available: false)
        let storedUseCase = CreatePersonalisedPlanUseCase(generator: unavailable, catalogue: catalogue, repository: plans)
        var input = OnboardingInput()
        input.age = "29"
        input.height = "165"
        input.weight = "62"
        input.selectedGoalID = "buildStrength"
        let viewModel = OnboardingViewModel(goals: [Goal(id: "buildStrength", title: "Get stronger", requiresTargetWeight: false)],
                                           exercises: catalogue, input: input,
                                           saveProfile: SaveOnboardingProfileUseCase(repository: profiles), createPlan: storedUseCase)
        await viewModel.buildPlan()
        #expect(viewModel.generationPhase == .ready)
        #expect(viewModel.plannerLabel == "HerLift rules")
        let profileID = try #require(profiles.profiles.first?.id)
        #expect(try context.fetchCount(FetchDescriptor<UserProfile>()) == 1)
        #expect(viewModel.plan?.profile.id == profileID)
        let reopened = try SwiftDataTrainingPlanRepository(modelContext: ModelContext(container))
        let restored = try CreatePersonalisedPlanUseCase(generator: unavailable, catalogue: catalogue, repository: reopened).loadSavedPlan()
        #expect(restored?.id == viewModel.plan?.id)
        #expect(restored?.days.count == 3)
        let restoredViewModel = OnboardingViewModel(goals: viewModel.goals, exercises: catalogue,
                                                   createPlan: CreatePersonalisedPlanUseCase(generator: unavailable, catalogue: catalogue, repository: reopened))
        restoredViewModel.load(using: LoadOnboardingProfileUseCase(repository: profiles))
        restoredViewModel.loadSavedPlan()
        #expect(restoredViewModel.generationPhase == .ready)
        #expect(restoredViewModel.plannerLabel == "HerLift rules")
        viewModel.changeAnswers()
        #expect(viewModel.generationPhase == .editing)
        #expect(try plans.load().isEmpty)
        viewModel.input.weight = "63"
        await viewModel.buildPlan()
        #expect(viewModel.plan?.profile.weightKg == 63)
        #expect(viewModel.plan?.profile.id == profileID)
        await viewModel.buildPlan()
        #expect(try plans.load().count == 1)
        #expect(try context.fetchCount(FetchDescriptor<WorkoutDay>()) == 3)
        #expect(try context.fetchCount(FetchDescriptor<UserProfile>()) == 1)
        let saved = try #require(viewModel.plan)
        saved.statusRaw = "active"
        try context.save()
        await viewModel.buildPlan()
        #expect(try plans.load().filter { $0.statusRaw == "active" }.count == 1)
        #expect(try plans.load().filter { $0.statusRaw == "draft" }.count == 1)
        let failingStore = FailingPlanRepository()
        let cannotSave = CreatePersonalisedPlanUseCase(generator: ai, catalogue: catalogue, repository: failingStore)
        await #expect(throws: CreatePersonalisedPlanError.couldNotSavePlan) { try await cannotSave.execute(request) }
        #expect(failingStore.calls == 1)
        let profileFailure = ProfileRepositoryStub()
        let failingViewModel = OnboardingViewModel(goals: viewModel.goals, input: input,
                                                  saveProfile: SaveOnboardingProfileUseCase(repository: profileFailure), createPlan: cannotSave)
        await failingViewModel.buildPlan()
        #expect(failingViewModel.generationPhase == .failed)
        profileFailure.fails = true
        await failingViewModel.retryBuildPlan()
        #expect(failingViewModel.generationPhase == .editing)
        #expect(failingViewModel.error == .couldNotSaveProfile)
    }

    @Test func unavailableOrRepeatedlyInvalidAIUsesValidatedFallbackAndStopsOnCancellation() async throws {
        let catalogue = try JSONExerciseRepository().exercises
        let request = integrationRequest()
        let valid = try PlanRuleEngine().generate(request, catalogue: catalogue)
        for available in [false, true] {
            let ai = IntegrationGeneratorStub(kind: .onDeviceAI, plan: valid, invalidResponses: 2, available: available)
            let useCase = CreatePersonalisedPlanUseCase(generator: ai, catalogue: catalogue)
            let plan = try await useCase.execute(request)
            #expect(plan.generatorRaw == "ruleBased")
            #expect(ai.calls == (available ? 2 : 0))
            try PlanRuleEngine().validate(plan, request: request, catalogue: catalogue)
        }
        let ai = IntegrationGeneratorStub(kind: .onDeviceAI, plan: valid, invalidResponses: 2)
        let fallback = IntegrationGeneratorStub(kind: .ruleBased, plan: valid, invalidResponses: 1)
        let failing = CreatePersonalisedPlanUseCase(generator: ai, catalogue: catalogue, fallback: fallback)
        await #expect(throws: CreatePersonalisedPlanError.invalidTrainingPlan) { try await failing.execute(request) }
        #expect(fallback.calls == 1)
        let cancelledAI = IntegrationGeneratorStub(kind: .onDeviceAI, plan: valid)
        let cancelled = Task { @MainActor in
            withUnsafeCurrentTask { $0?.cancel() }
            _ = try await CreatePersonalisedPlanUseCase(generator: cancelledAI, catalogue: catalogue).execute(request)
        }
        await #expect(throws: CreatePersonalisedPlanError.invalidTrainingPlan) { try await cancelled.value }
        #expect(cancelledAI.calls == 0)
    }

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
        let useCase = CreatePersonalisedPlanUseCase(generator: stub, catalogue: testCatalogue)
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
        let useCase = CreatePersonalisedPlanUseCase(generator: stub, catalogue: testCatalogue)

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

    private final class FailingPlanRepository: TrainingPlanRepository {
        var plans: [TrainingPlan] = []
        var calls = 0
        func load() throws -> [TrainingPlan] { plans }
        func add(_ trainingPlan: TrainingPlan) throws {
            calls += 1
            throw CocoaError(.fileWriteUnknown)
        }
        func update(_ trainingPlan: TrainingPlan) throws {}
        func delete(_ trainingPlan: TrainingPlan) throws {}
    }

    private func integrationRequest() -> PlanRequest {
        PlanRequest(experience: .beginner, goalID: "buildStrength", targetWeightKg: nil,
                    trainingWeekdays: [1, 3, 6], sessionMinutes: 45, age: 29,
                    heightCm: 165, weightKg: 62, healthNote: nil, clearedByDoctor: false)
    }

    @MainActor
    private final class IntegrationGeneratorStub: PlanGenerating {
        nonisolated let kind: PlanGeneratorKind
        nonisolated let isAvailable: Bool
        private let plan: TrainingPlan
        private let invalidResponses: Int
        private(set) var calls = 0
        private(set) var feedback: [CreatePersonalisedPlanError?] = []

        init(kind: PlanGeneratorKind, plan: TrainingPlan, invalidResponses: Int = 0, available: Bool = true) {
            self.kind = kind
            self.plan = plan
            self.invalidResponses = invalidResponses
            isAvailable = available
        }

        nonisolated func generate(_ request: PlanRequest) async throws(CreatePersonalisedPlanError) -> TrainingPlan {
            try await generate(request, validationFeedback: nil)
        }

        nonisolated func generate(_ request: PlanRequest, validationFeedback: CreatePersonalisedPlanError?) async throws(CreatePersonalisedPlanError) -> TrainingPlan {
            await response(validationFeedback)
        }

        private func response(_ validationFeedback: CreatePersonalisedPlanError?) -> TrainingPlan {
            calls += 1
            feedback.append(validationFeedback)
            guard calls <= invalidResponses else { return plan }
            return TrainingPlan(profile: plan.profile, goalRaw: plan.goalRaw, strategyRaw: plan.strategyRaw,
                                generatorRaw: kind.rawValue, coachText: "")
        }
    }

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
            let plan = try await validPlan(request)
            lastPlan = plan
            return plan
        }

        @MainActor private func validPlan(_ request: PlanRequest) throws(CreatePersonalisedPlanError) -> TrainingPlan {
            let catalogue = (try? JSONExerciseRepository().exercises) ?? []
            return try PlanRuleEngine().generate(request, catalogue: catalogue)
        }

    }

    private var testCatalogue: [Exercise] { try! JSONExerciseRepository().exercises }

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
            createPlan: CreatePersonalisedPlanUseCase(generator: stub, catalogue: testCatalogue)
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
