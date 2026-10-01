import Foundation

nonisolated protocol PlanGenerating: Sendable {
    var kind: PlanGeneratorKind { get }
    func generate(_ request: PlanRequest) async throws(CreatePersonalisedPlanError) -> TrainingPlan
}

/// Error copy follows HERLIFT_USE_CASES.md UC1 and the approved draft copy in
/// UI_DESIGN.md §10; the frequency and duration wording matches amendment A8.
nonisolated enum CreatePersonalisedPlanError: Error, LocalizedError, Equatable {
    case missingGoal
    case unsupportedTrainingFrequency
    case invalidSessionDuration
    case medicalClearanceRequired
    case unsafeTargetWeight
    case noSuitableExercises
    case couldNotSavePlan
    case planDraftInvalid

    var errorDescription: String? {
        switch self {
        case .missingGoal: "Your Coach needs a goal to plan around."
        case .unsupportedTrainingFrequency: "HerLift plans around the days you choose — 2 to 7 a week."
        case .invalidSessionDuration: "Choose 30–120 minutes, in steps of 5."
        case .medicalClearanceRequired: "Please check with your doctor before you start."
        case .unsafeTargetWeight: "This target is below a healthy weight for your height."
        case .noSuitableExercises: "We couldn't find enough beginner exercises for this goal."
        case .couldNotSavePlan: "We couldn't save your new plan."
        case .planDraftInvalid: "We couldn't build your plan. Your answers are saved."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .missingGoal: "Choose at least one goal, then tap Build my plan."
        case .unsupportedTrainingFrequency, .invalidSessionDuration: "Check your answers in Your training and try again."
        case .medicalClearanceRequired: "Tick that a doctor has cleared you to exercise in About you — your plan will start gently."
        case .unsafeTargetWeight: "Choose a target that keeps you above a healthy weight for your height."
        case .noSuitableExercises: "Try a different goal or add a training day."
        case .couldNotSavePlan: "Your answers are still here — tap Build my plan again."
        case .planDraftInvalid: "Try again or change my answers."
        }
    }
}
