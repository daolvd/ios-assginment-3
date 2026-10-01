import Foundation

/// UC1, input half: validate the request, then delegate drafting to the
/// generator. Screening (A4) blocks a health note without a doctor's all-clear
/// before any generator runs. Validation, retry-once and the rule-based
/// fallback arrive with the rule-based generator (TASKS G5.2–G5.4).
@MainActor
struct CreatePersonalisedPlanUseCase {
    let generator: any PlanGenerating

    var plannerLabel: String { generator.kind.label }

    func execute(_ request: PlanRequest) async throws(CreatePersonalisedPlanError) -> TrainingPlan {
        guard !request.goalID.isEmpty else { throw .missingGoal }
        guard (2...7).contains(request.trainingWeekdays.count),
              request.trainingWeekdays.allSatisfy({ (1...7).contains($0) }) else {
            throw .unsupportedTrainingFrequency
        }
        guard (30...120).contains(request.sessionMinutes), request.sessionMinutes.isMultiple(of: 5) else {
            throw .invalidSessionDuration
        }
        if let note = request.healthNote, !note.isEmpty, !request.clearedByDoctor {
            throw .medicalClearanceRequired
        }
        return try await generator.generate(request)
    }
}
