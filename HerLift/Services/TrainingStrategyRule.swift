import Foundation

/// Group 1 of the FITT-VP rule engine: screening, strategy and weekly limits.
/// It reads a value profile only; it does not select exercises or write SwiftData.
nonisolated struct TrainingStrategyRule {
    func evaluate(_ profile: OnboardingProfile) -> PlanScreeningResult {
        let hasHealthNote = !(profile.healthNote?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        guard !hasHealthNote || profile.clearedByDoctor else { return .medicalClearanceRequired }

        let bmi = profile.weightKg * 10_000 / (profile.heightCm * profile.heightCm)
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

    var needsLongerRest: Bool { isConservative || isLowImpact || isOlderBeginner }
    var requiresGuidedEquipment: Bool { isConservative }
    var prefersMachineFirst: Bool { isLowImpact || isOlderBeginner }
    var maximumSetsPerExercise: Int { isConservative || isOlderBeginner ? 2 : 3 }
}

/// Hard ceilings and soft weekly targets used by the scheduler in the next group.
nonisolated struct WeeklyVolumePolicy: Equatable, Sendable {
    let desiredSets: Int
    let maximumSets: Int
    let maximumMajorMuscleSets: Int

    init(profile: OnboardingProfile, strategy: TrainingStrategy) {
        let reducedInitialVolume = strategy.isConservative || strategy.isOlderBeginner
        desiredSets = reducedInitialVolume ? 16 : 24
        maximumSets = reducedInitialVolume || profile.trainingWeekdays.count == 7 ? 24 : 32
        maximumMajorMuscleSets = reducedInitialVolume ? 6 : 8
    }
}
