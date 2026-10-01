import Foundation

/// Deterministic body-metric rules. BMI is a rough signal that shapes strategy
/// and safety gates; it is never shown to her as a judgement.
nonisolated enum PlanRules {
    /// BMI = kg / m². Nil when either metric is not a positive finite number.
    static func bmi(weightKg: Double, heightCm: Double) -> Double? {
        guard weightKg.isFinite, weightKg > 0, heightCm.isFinite, heightCm > 0 else { return nil }
        let result = weightKg * 10_000 / (heightCm * heightCm)
        return result.isFinite && result > 0 ? result : nil
    }

    /// A Lose-fat target must keep her BMI at 18.5 or above, else `unsafeTargetWeight`.
    static func isSafeTargetWeight(_ targetWeightKg: Double, heightCm: Double) -> Bool {
        guard let targetBMI = bmi(weightKg: targetWeightKg, heightCm: heightCm) else { return false }
        return targetBMI >= 18.5
    }
}
