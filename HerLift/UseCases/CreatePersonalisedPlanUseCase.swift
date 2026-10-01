import Foundation
import OSLog
@MainActor
struct CreatePersonalisedPlanUseCase {
    let generator: any PlanGenerating
    private let catalogue: [Exercise]
    private let fallback: any PlanGenerating
    private let repository: (any TrainingPlanRepository)?
    private static let logger = Logger(subsystem: "HerLift", category: "Planning")

    init(generator: any PlanGenerating, catalogue: [Exercise], fallback: (any PlanGenerating)? = nil,
         repository: (any TrainingPlanRepository)? = nil) {
        self.generator = generator
        self.catalogue = catalogue
        self.fallback = fallback ?? RuleBasedPlanGenerator(catalogue: catalogue)
        self.repository = repository
    }

    var plannerLabel: String { (generator.isAvailable ? generator : fallback).kind.label }

    /// EN: Screen first, try AI at most twice, then use the independent rules fallback.
    /// VI: Kiểm tra trước, thử AI tối đa hai lần, rồi dùng fallback độc lập bằng rule.
    func execute(_ request: PlanRequest) async throws(CreatePersonalisedPlanError) -> TrainingPlan {
        _ = try PlanRuleEngine().prepare(request, catalogue: catalogue)
        try checkCancellation()
        var feedback: CreatePersonalisedPlanError?
        for attempt in 0..<2 {
            guard generator.isAvailable else { break }
            do {
                let plan = try await generator.generate(request, validationFeedback: feedback)
                try checkCancellation()
                try validate(plan, request: request, source: generator.kind)
                return try save(plan)
            } catch {
                try checkCancellation()
                guard generator.kind == .onDeviceAI, error == .invalidTrainingPlan else { throw error }
                feedback = error
                if attempt == 0 { Self.logger.info("AI plan rejected; retrying once.") }
            }
        }
        Self.logger.info("Using rules fallback for plan generation.")
        let plan = try await fallback.generate(request)
        try checkCancellation()
        try validate(plan, request: request, source: fallback.kind)
        return try save(plan)
    }

    private func validate(_ plan: TrainingPlan, request: PlanRequest, source: PlanGeneratorKind) throws(CreatePersonalisedPlanError) {
        guard plan.statusRaw == "draft", plan.generatorRaw == source.rawValue else { throw .invalidTrainingPlan }
        try PlanRuleEngine().validate(plan, request: request, catalogue: catalogue)
    }

    private func checkCancellation() throws(CreatePersonalisedPlanError) {
        guard !Task.isCancelled else { throw .invalidTrainingPlan }
    }

    private func save(_ plan: TrainingPlan) throws(CreatePersonalisedPlanError) -> TrainingPlan {
        try checkCancellation()
        do { try repository?.add(plan) }
        catch { throw .couldNotSavePlan }
        return plan
    }

    /// EN: Restore the latest plan awaiting acceptance, checking it before showing it again.
    /// VI: Khôi phục plan mới nhất đang chờ chấp nhận, kiểm tra trước khi hiển thị lại.
    func loadSavedPlan() throws(CreatePersonalisedPlanError) -> TrainingPlan? {
        let plan: TrainingPlan?
        do { plan = try repository?.load().last { $0.statusRaw == "draft" } }
        catch { throw .invalidTrainingPlan }
        guard let plan, let experience = ExperienceLevel(rawValue: plan.profile.experienceRaw) else { return nil }
        let profile = plan.profile
        let request = PlanRequest(experience: experience, goalID: plan.goalRaw, targetWeightKg: plan.targetWeightKg,
                                  trainingWeekdays: profile.trainingWeekdays, sessionMinutes: profile.sessionMinutes,
                                  age: profile.age, heightCm: profile.heightCm, weightKg: profile.weightKg,
                                  healthNote: profile.healthNote, clearedByDoctor: profile.clearedByDoctor)
        try PlanRuleEngine().validate(plan, request: request, catalogue: catalogue)
        return plan
    }

    func discard(_ plan: TrainingPlan) throws(CreatePersonalisedPlanError) {
        guard plan.statusRaw == "draft" else { return }
        do { try repository?.delete(plan) }
        catch { throw .couldNotSavePlan }
    }

    func milestones(for goalID: String) -> [String] {
        PlanRuleEngine().milestones(for: goalID)
    }
}
