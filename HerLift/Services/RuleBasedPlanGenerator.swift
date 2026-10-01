import Foundation

@MainActor
final class RuleBasedPlanGenerator: PlanGenerating {
    nonisolated let kind = PlanGeneratorKind.ruleBased
    private let catalogue: [Exercise]

    init(catalogue: [Exercise]) { self.catalogue = catalogue }

    /// EN: The fallback uses rules only; it never calls the AI model.
    /// VI: Fallback chỉ dùng rule; không gọi model AI.
    nonisolated func generate(_ request: PlanRequest) async throws(CreatePersonalisedPlanError) -> TrainingPlan {
        try await build(request)
    }

    private func build(_ request: PlanRequest) throws(CreatePersonalisedPlanError) -> TrainingPlan {
        guard !Task.isCancelled else { throw .invalidTrainingPlan }
        return try PlanRuleEngine().generate(request, catalogue: catalogue)
    }
}
