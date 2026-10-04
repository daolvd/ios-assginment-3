import Foundation

/// The numbers behind a plan's forecast. Deterministic: the same answers always give the same weeks.
nonisolated enum ForecastCalculator {
    static let loseFatGoalID = "loseFat"
    static let disclaimer = "A forecast, not a promise: it assumes you follow the plan and watch what you eat. Real results may differ."

    /// A target weight below this body mass index is never offered.
    static let minimumHealthyBMI = 18.5
    static let fastestLossKgPerWeek = 1.0
    static let slowestLossKgPerWeek = 0.5

    static func isHealthyTarget(_ targetKg: Double, heightCm: Double) -> Bool {
        targetKg * 10_000 / (heightCm * heightCm) >= minimumHealthyBMI
    }

    /// The lowest whole kilogram target that keeps the body mass index at or above the minimum.
    static func minimumHealthyWeightKg(heightCm: Double) -> Int {
        Int((minimumHealthyBMI * heightCm * heightCm / 10_000).rounded(.up))
    }

    /// The weeks a fat-loss goal may take, or nil when the goal is not fat loss.
    static func weightLossForecast(for user: UserPlanningProfile) throws(PlanningError) -> WeightLossForecast? {
        guard user.goalID == loseFatGoalID else { return nil }
        guard let current = user.weightKg, let height = user.heightCm, let target = user.targetWeightKg,
              current > 0, height > 0, target > 0
        else { throw .targetWeightRequired }

        guard isHealthyTarget(target, heightCm: height) else {
            throw .unsafeTargetWeight(minimumKg: minimumHealthyWeightKg(heightCm: height))
        }
        guard target < current else { throw .targetNotBelowCurrent }

        let toLose = current - target
        let earliest = max(1, Int((toLose / fastestLossKgPerWeek).rounded(.up)))
        let latest = max(earliest, Int((toLose / slowestLossKgPerWeek).rounded(.up)))
        return WeightLossForecast(currentKg: current, targetKg: target, earliestWeek: earliest, latestWeek: latest)
    }

    static func milestones(for goalID: Goal.ID) -> [ForecastMilestone] {
        let learn = ForecastMilestone(startWeek: 1, endWeek: 2, title: "Learn the moves, find starting weights")
        let onYourOwn = ForecastMilestone(startWeek: 4, endWeek: 4, title: "All exercises on your own")
        let review = ForecastMilestone(startWeek: 12, endWeek: 12, title: "Goal review")

        switch goalID {
        case loseFatGoalID:
            return [learn, onYourOwn, review]
        case "buildMuscle", "buildStrength":
            return [
                learn,
                ForecastMilestone(startWeek: 3, endWeek: 6, title: "Add weight gradually"),
                ForecastMilestone(startWeek: 8, endWeek: 8, title: "Strength check"),
                review,
            ]
        case "increaseGymConfidence":
            return [learn, onYourOwn]
        default:
            return []
        }
    }
}
