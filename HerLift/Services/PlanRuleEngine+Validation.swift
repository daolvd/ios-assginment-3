import Foundation

@MainActor
extension PlanRuleEngine {
    /// EN: Recheck the completed plan, even if the scheduler already checked each choice. AI uses these checks too.
    /// VI: Kiểm tra lại plan đã hoàn thành, dù từng lựa chọn đã được kiểm tra. Lịch AI cũng dùng các kiểm tra này.
    func validate(_ plan: TrainingPlan, context: Context, requireFullSessions: Bool = true) throws(CreatePersonalisedPlanError) {
        let request = context.request, days = plan.days
        try validateMetadata(plan, context: context)
        var total = 0, direct: [MuscleGroup: Int] = [:], muscles: [Int: Set<MuscleGroup>] = [:], movements: Set<MovementPattern> = []
        for day in days {
            // EN: Each day must belong to this plan, contain exercises, have no duplicate exercises and have valid order numbers.
            // VI: Mỗi ngày phải thuộc plan này, có bài tập, không trùng bài và có số thứ tự hợp lệ.
            guard day.plan.id == plan.id, !day.exercises.isEmpty,
                  Set(day.exercises.map(\.exerciseID)).count == day.exercises.count,
                  day.exercises.map(\.sortIndex).sorted() == Array(day.exercises.indices) else { throw .invalidTrainingPlan }
            for target in day.exercises {
                // EN: Each exercise must be allowed, with the expected reps/rest and no guessed starting weight.
                // VI: Mỗi bài phải được phép, có số lần lặp/nghỉ đúng và chưa bị đoán mức tạ ban đầu.
                // EN: Standard allows 1–3 sets; a strategy limited to 2 sets requires exactly 2.
                // VI: Standard cho phép 1–3 sets; chế độ giới hạn 2 sets yêu cầu đúng 2.
                guard let entry = context.entries.first(where: { $0.exercise.id == target.exerciseID }),
                      target.workoutDay.id == day.id, (1...context.strategy.maximumSetsPerExercise).contains(target.targetSets),
                      context.strategy.maximumSetsPerExercise != 2 || target.targetSets == 2,
                      target.minimumReps == entry.exercise.minimumReps, target.maximumReps == entry.exercise.maximumReps,
                      target.restSeconds == PlanRuleMath.rest(entry.exercise, strategy: context.strategy), target.targetWeightKg == nil else { throw .invalidTrainingPlan }
                total += target.targetSets
                // EN: Add sets only to the primary muscle. Example: a chest exercise with 2 sets adds 2 chest sets, not extra arm sets.
                // VI: Chỉ cộng sets cho cơ chính. Ví dụ: bài ngực 2 sets cộng 2 sets ngực, không cộng thêm sets tay.
                direct[entry.muscle, default: 0] += target.targetSets
                muscles[day.weekday, default: []].insert(entry.muscle)
                movements.insert(entry.movement)
            }
            guard day.estimatedMinutes == (try PlanRuleMath.estimatedMinutes(day.exercises)), day.estimatedMinutes <= request.sessionMinutes else { throw .invalidTrainingPlan }
        }
        // EN: Reject sets beyond the time-derived week capacity or the independent muscle limits.
        // VI: Loại sets vượt sức chứa tuần tính từ thời gian hoặc vượt giới hạn riêng của nhóm cơ.
        guard total <= context.volume.maximumSets, requiredMovements.isSubset(of: movements),
              majorMuscles.allSatisfy({ direct[$0, default: 0] <= context.volume.maximumMajorMuscleSets }) else { throw .invalidTrainingPlan }
        for (weekday, primary) in muscles {
            // EN: Check the next day, including Sunday → Monday, for repeated primary muscles.
            // VI: Kiểm tra cơ chính bị trùng với ngày tiếp theo, kể cả Chủ nhật → thứ Hai.
            guard primary.isDisjoint(with: muscles[weekday % 7 + 1, default: []]) else { throw .invalidTrainingPlan }
        }
        let forecast = try PlanRuleMath.forecastWeeks(request)
        guard plan.forecastMinWeeks == forecast.min, plan.forecastMaxWeeks == forecast.max else { throw .invalidTrainingPlan }
        if requireFullSessions {
            try validateSessionUtilization(plan, context: context, totalSets: total, directSets: direct, muscles: muscles)
        }
    }

    /// EN: Reject a NEW plan if a session still has room for another legal exercise; retry AI or use fallback.
    /// VI: Loại plan MỚI nếu buổi vẫn còn chỗ thêm bài hợp lệ; thử lại AI hoặc dùng fallback.
    /// EN: Use actual saved sets/rest. A shorter session is allowed when muscle limits, recovery or catalogue block additions.
    /// VI: Dùng sets/nghỉ thực tế đã lưu. Cho phép buổi ngắn hơn khi giới hạn cơ, phục hồi hoặc catalogue chặn thêm bài.
    private func validateSessionUtilization(_ plan: TrainingPlan, context: Context, totalSets: Int,
                                           directSets: [MuscleGroup: Int], muscles: [Int: Set<MuscleGroup>]) throws(CreatePersonalisedPlanError) {
        for day in plan.days {
            let usedIDs = Set(day.exercises.map(\.exerciseID))
            let neighboringMuscles = muscles.filter { PlanRuleMath.adjacent($0.key, day.weekday) }.values.reduce(into: Set<MuscleGroup>()) { $0.formUnion($1) }
            for entry in context.entries {
                guard !usedIDs.contains(entry.exercise.id), !neighboringMuscles.contains(entry.muscle),
                      totalSets + PlanRuleMath.initialSets <= context.volume.maximumSets,
                      !entry.major || directSets[entry.muscle, default: 0] + PlanRuleMath.initialSets <= context.volume.maximumMajorMuscleSets else { continue }
                let expanded = day.exercises.map { (sets: $0.targetSets, rest: $0.restSeconds) }
                    + [(sets: PlanRuleMath.initialSets, rest: PlanRuleMath.rest(entry.exercise, strategy: context.strategy))]
                guard PlanRuleMath.sessionSeconds(expanded) > context.request.sessionMinutes * 60 else { throw .invalidTrainingPlan }
            }
        }
    }

    /// EN: Match the plan back to the original answers, generator type and expected number of training days.
    /// VI: Đối chiếu plan với câu trả lời ban đầu, nguồn tạo lịch và số ngày tập cần có.
    /// EN: Selecting all 7 days keeps 7 in the profile but requires 6 actual training days.
    /// VI: Chọn cả 7 ngày thì profile vẫn giữ 7 ngày, nhưng lịch phải có 6 ngày tập thực tế.
    private func validateMetadata(_ plan: TrainingPlan, context: Context) throws(CreatePersonalisedPlanError) {
        let request = context.request, days = plan.days
        let selected = Set(request.trainingWeekdays), actual = Set(days.map(\.weekday))
        guard actual.count == days.count, actual.count == min(selected.count, 6), actual.isSubset(of: selected),
              days.map(\.sortIndex).sorted() == Array(days.indices), plan.goalRaw == request.goalID,
              plan.strategyRaw == context.strategy.rawValue, plan.targetWeeks == 12,
              PlanGeneratorKind(rawValue: plan.generatorRaw) != nil,
              plan.profile.age == request.age, plan.profile.heightCm == request.heightCm, plan.profile.weightKg == request.weightKg,
              plan.profile.experienceRaw == request.experience.rawValue,
              plan.profile.trainingWeekdays.sorted() == request.trainingWeekdays.sorted(),
              plan.profile.sessionMinutes == request.sessionMinutes, plan.profile.healthNote == request.healthNote,
              plan.profile.clearedByDoctor == request.clearedByDoctor,
              plan.targetWeightKg == (context.goal == .loseFat ? request.targetWeightKg : nil) else { throw .invalidTrainingPlan }
    }
}
