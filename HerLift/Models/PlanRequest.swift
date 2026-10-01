import Foundation

/// Everything the generator may read: the saved answers plus the chosen goal.
/// The domain calculates BMI, strategy and forecasts from these; the model never does.
nonisolated struct PlanRequest: Equatable, Sendable {
    let experience: ExperienceLevel
    let goalID: String
    /// Set only when the goal requires a target weight.
    let targetWeightKg: Double?
    /// Monday = 1, Sunday = 7, already sorted. The count is 2–7 (A8).
    let trainingWeekdays: [Int]
    /// 30–120 minutes, in steps of 5.
    let sessionMinutes: Int
    let age: Int
    let heightCm: Double
    let weightKg: Double
    let healthNote: String?
    let clearedByDoctor: Bool
}

/// Shown on the Building screen so she knows who wrote the draft.
nonisolated enum PlanGeneratorKind: String, Sendable {
    case onDeviceAI
    case ruleBased

    var label: String {
        switch self {
        case .onDeviceAI: "On-device AI"
        case .ruleBased: "HerLift rules"
        }
    }
}
