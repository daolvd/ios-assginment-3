import Foundation

/// Screens health clearance and combines the applicable training limits.
/// It reads a value profile only; it does not select exercises or write SwiftData.
nonisolated struct TrainingStrategyRule {
    func evaluate(_ profile: OnboardingProfile) -> PlanScreeningResult {
        let hasHealthNote = !(profile.healthNote?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        guard !hasHealthNote || profile.clearedByDoctor else { return .medicalClearanceRequired }

        let bmi = PlanRules.bmi(weightKg: profile.weightKg, heightCm: profile.heightCm) ?? 0
        return .ready(TrainingStrategy(
            isConservative: hasHealthNote,
            isLowImpact: bmi >= 30,
            isOlderBeginner: profile.age >= 50
        ))
    }
}

nonisolated enum PlanScreeningResult: Equatable, Sendable {
    case ready(TrainingStrategy)
    case medicalClearanceRequired
}

/// Combined flags are retained: a single strategy never hides another limit.
nonisolated struct TrainingStrategy: Equatable, Sendable {
    let isConservative: Bool
    let isLowImpact: Bool
    let isOlderBeginner: Bool

    var rawValue: String {
        var flags: [String] = []
        if isConservative { flags.append("conservative") }
        if isLowImpact { flags.append("lowImpact") }
        if isOlderBeginner { flags.append("olderBeginner") }
        return flags.isEmpty ? "standard" : flags.joined(separator: "+")
    }

    var needsLongerRest: Bool { isConservative || isLowImpact || isOlderBeginner }
    var requiresGuidedEquipment: Bool { isConservative }
    var prefersMachineFirst: Bool { isLowImpact || isOlderBeginner }
    var maximumSetsPerExercise: Int { isConservative || isOlderBeginner ? 2 : 3 }
}

/// EN: The total week capacity comes from each session's available time; muscle limits remain separate.
/// VI: Sức chứa cả tuần được tính từ thời gian từng buổi; giới hạn nhóm cơ được kiểm tra riêng.
nonisolated struct WeeklyVolumePolicy: Equatable, Sendable {
    let maximumSets: Int
    let maximumMajorMuscleSets: Int

    init(profile: OnboardingProfile, strategy: TrainingStrategy, minimumRestSeconds: Int, exerciseCount: Int) {
        let reducedInitialVolume = strategy.isConservative || strategy.isOlderBeginner
        let capacityPerSession = PlanRuleMath.maximumSessionSets(minutes: profile.sessionMinutes,
            minimumRestSeconds: minimumRestSeconds, exerciseCount: exerciseCount)
        maximumSets = capacityPerSession * min(profile.trainingWeekdays.count, 6)
        maximumMajorMuscleSets = reducedInitialVolume ? 6 : 8
    }
}
