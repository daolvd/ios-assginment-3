import Foundation

nonisolated enum PlanRuleMath {
    static let initialSets = 2
    private static let warmupSeconds = 300
    private static let secondsPerSet = 45
    private static let transitionSeconds = 60
    private static let extraRestSeconds = 30
    private static let minimumWeeklyWeightLossKg = 0.5
    private static let maximumWeeklyWeightLossKg = 1.0

    static func rest(_ exercise: Exercise, strategy: TrainingStrategy) -> Int {
        exercise.defaultRestSeconds + (strategy.needsLongerRest ? extraRestSeconds : 0)
    }

    static func adjacent(_ a: Int, _ b: Int) -> Bool {
        (a - b + 7) % 7 == 1 || (b - a + 7) % 7 == 1
    }

    static func sessionSeconds(_ targets: [(sets: Int, rest: Int)]) -> Int {
        warmupSeconds + targets.reduce(0) { $0 + $1.sets * secondsPerSet + ($1.sets - 1) * $1.rest }
            + max(0, targets.count - 1) * transitionSeconds
    }

    @MainActor
    static func estimatedMinutes(_ exercises: [PlannedExercise]) throws(CreatePersonalisedPlanError) -> Int {
        guard !exercises.isEmpty, exercises.count <= 32,
              exercises.allSatisfy({ (1...3).contains($0.targetSets) && (1...630).contains($0.restSeconds) })
        else { throw .invalidTrainingPlan }
        let seconds = sessionSeconds(exercises.map { (sets: $0.targetSets, rest: $0.restSeconds) })
        return (seconds + 59) / 60
    }

    static func forecastWeeks(_ request: PlanRequest) throws(CreatePersonalisedPlanError) -> (min: Int?, max: Int?) {
        guard PlanGoalKind(rawValue: request.goalID) == .loseFat, let target = request.targetWeightKg else { return (nil, nil) }
        let difference = request.weightKg - target
        let maximum = ceil(difference / minimumWeeklyWeightLossKg)
        guard maximum.isFinite, maximum < Double(Int.max) else { throw .invalidTrainingPlan }
        return (Int(ceil(difference / maximumWeeklyWeightLossKg)), Int(maximum))
    }

    static func title(_ muscles: [MuscleGroup]) -> String {
        let groups = Set(muscles).subtracting([.core])
        if groups.isSubset(of: MuscleGroup.lowerBody) { return "Lower body" }
        if groups.isDisjoint(with: MuscleGroup.lowerBody) { return "Upper body" }
        return "Full body"
    }
}
