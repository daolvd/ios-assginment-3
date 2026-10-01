import Foundation

nonisolated enum PlanRuleMath {
    static let initialSets = 2
    private static let warmupSeconds = 300
    private static let secondsPerSet = 45
    private static let transitionSeconds = 60
    private static let extraRestSeconds = 30
    private static let minimumWeeklyWeightLossKg = 0.5
    private static let maximumWeeklyWeightLossKg = 1.0

    /// EN: Add 30 seconds of rest once if any condition requires longer rest; two conditions still add only 30.
    /// VI: Cộng 30 giây nghỉ một lần nếu có điều kiện cần nghỉ lâu; có hai điều kiện vẫn chỉ cộng 30.
    static func rest(_ exercise: Exercise, strategy: TrainingStrategy) -> Int {
        exercise.defaultRestSeconds + (strategy.needsLongerRest ? extraRestSeconds : 0)
    }

    /// EN: Days use 1 = Monday through 7 = Sunday. Sunday and Monday are adjacent.
    /// VI: Ngày dùng 1 = thứ Hai đến 7 = Chủ nhật. Chủ nhật và thứ Hai là liền nhau.
    static func adjacent(_ a: Int, _ b: Int) -> Bool {
        (a - b + 7) % 7 == 1 || (b - a + 7) % 7 == 1
    }

    /// EN: Time = 5-minute warmup + 45 seconds per set + rest between sets + 1 minute between exercises.
    /// VI: Thời gian = 5 phút khởi động + 45 giây mỗi set + nghỉ giữa sets + 1 phút giữa hai bài.
    /// EN: Example: 2 exercises, each with 2 sets and 60-second rest → 300 + 180 + 120 + 60 = 660 seconds (11 minutes).
    /// VI: Ví dụ: 2 bài, mỗi bài 2 sets và nghỉ 60 giây → 300 + 180 + 120 + 60 = 660 giây (11 phút).
    /// EN: Do not add rest after the last set or transition time after the last exercise.
    /// VI: Không cộng nghỉ sau set cuối hoặc thời gian đổi bài sau bài cuối.
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
        // EN: Round up to full minutes. Example: 661 seconds is shown as 12 minutes.
        // VI: Làm tròn lên phút nguyên. Ví dụ: 661 giây được hiển thị thành 12 phút.
        return (seconds + 59) / 60
    }

    /// EN: Estimate weight-loss weeks using 1 kg/week for the shorter estimate and 0.5 kg/week for the longer one.
    /// VI: Ước tính số tuần giảm cân: dùng 1 kg/tuần cho mốc ngắn và 0.5 kg/tuần cho mốc dài.
    /// EN: Example: losing 5 kg gives 5–10 weeks. Round up partial weeks; the estimate may exceed the 12-week plan.
    /// VI: Ví dụ: giảm 5 kg cho khoảng 5–10 tuần. Làm tròn tuần lẻ lên; ước tính có thể vượt plan 12 tuần.
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
