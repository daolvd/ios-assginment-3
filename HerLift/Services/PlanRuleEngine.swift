import Foundation

@MainActor
/// EN: Check answers → keep suitable exercises → fill training days → calculate sets/rest → check the result.
/// VI: Kiểm tra câu trả lời → giữ bài phù hợp → thêm bài vào ngày tập → tính sets/nghỉ → kiểm tra kết quả.
/// EN: The plan stays in memory. This service does not save it to the database.
/// VI: Plan chỉ nằm trong bộ nhớ. Service này không lưu database.
struct PlanRuleEngine {
    /// EN: Return the exercises another scheduler, including AI, is allowed to choose.
    /// VI: Trả về danh sách bài mà bên xếp lịch khác, kể cả AI, được phép chọn.
    func eligibleExercises(for request: PlanRequest, catalogue: [Exercise]) throws(CreatePersonalisedPlanError) -> [Exercise] {
        try prepare(request, catalogue: catalogue).entries.map(\.exercise)
    }

    /// EN: Build a weekly schedule using fixed rules. The same answers and exercise list give the same schedule.
    /// VI: Tạo lịch một tuần bằng quy tắc cố định. Cùng câu trả lời và danh sách bài sẽ cho cùng lịch.
    func generate(_ request: PlanRequest, catalogue: [Exercise]) throws(CreatePersonalisedPlanError) -> TrainingPlan {
        let context = try prepare(request, catalogue: catalogue)
        let selected = request.trainingWeekdays.sorted()
        let days = try selectSchedule(context: context)
        // EN: Keep the original selected days. Choosing all 7 days still produces 6 training days and 1 rest day.
        // VI: Giữ nguyên các ngày đã chọn. Chọn cả 7 ngày vẫn tạo 6 ngày tập và 1 ngày nghỉ.
        let profile = UserProfile(age: request.age, heightCm: request.heightCm, weightKg: request.weightKg,
            experienceRaw: request.experience.rawValue, trainingWeekdays: selected, sessionMinutes: request.sessionMinutes,
            healthNote: request.healthNote, clearedByDoctor: request.clearedByDoctor)
        let plan = TrainingPlan(profile: profile, goalRaw: request.goalID, strategyRaw: context.strategy.rawValue,
                                generatorRaw: PlanGeneratorKind.ruleBased.rawValue, coachText: "")
        plan.days = days.enumerated().map { index, selection in
            let day = WorkoutDay(plan: plan, sortIndex: index, weekday: selection.weekday, title: PlanRuleMath.title(selection.entries.map(\.muscle)), estimatedMinutes: 0)
            // EN: Decide which exercise to do first. If two exercises have equal priority, use alphabetical ID order.
            // VI: Chọn bài nào làm trước. Nếu hai bài có cùng ưu tiên, sắp theo ID để kết quả không thay đổi.
            let ordered = selection.entries.sorted {
                let a = orderPriority($0, context: context), b = orderPriority($1, context: context)
                return a != b ? a > b : $0.exercise.id < $1.exercise.id
            }
            day.exercises = ordered.enumerated().map { index, entry in
                PlannedExercise(workoutDay: day, sortIndex: index, exerciseID: entry.exercise.id,
                    targetSets: PlanRuleMath.initialSets, minimumReps: entry.exercise.minimumReps, maximumReps: entry.exercise.maximumReps,
                    restSeconds: PlanRuleMath.rest(entry.exercise, strategy: context.strategy))
            }
            return day
        }
        // EN: Set the numbers for each exercise, then reject the plan if any required check fails.
        // VI: Điền các con số cho từng bài, rồi từ chối plan nếu có điều kiện bắt buộc không đạt.
        try applyRules(to: plan, context: context)
        try validate(plan, context: context)
        return plan
    }

    /// EN: Keep the chosen days and exercise order, but replace sets, reps, rest and duration with rule values.
    /// VI: Giữ ngày tập và thứ tự bài, nhưng tính lại sets, số lần lặp, nghỉ và thời lượng theo quy tắc.
    /// EN: This also works for an AI schedule. It changes the objects before the final check, even if that check fails.
    /// VI: Dùng được cho lịch AI. Object được sửa trước bước kiểm tra cuối, kể cả khi bước đó báo lỗi.
    func applyRules(to plan: TrainingPlan, request: PlanRequest, catalogue: [Exercise]) throws(CreatePersonalisedPlanError) {
        try applyRules(to: plan, context: prepare(request, catalogue: catalogue))
        try validate(plan, request: request, catalogue: catalogue)
    }

    private func applyRules(to plan: TrainingPlan, context: Context) throws(CreatePersonalisedPlanError) {
        // EN: Only edit a plan awaiting acceptance, and only if every exercise ID is in the allowed list.
        // VI: Chỉ sửa plan đang chờ chấp nhận, và mọi ID bài phải nằm trong danh sách được phép.
        guard plan.statusRaw == "draft", plan.days.flatMap(\.exercises).allSatisfy({ target in
            context.entries.contains { $0.exercise.id == target.exerciseID }
        }) else { throw .invalidTrainingPlan }
        for (index, day) in plan.days.sorted(by: { $0.weekday < $1.weekday }).enumerated() {
            day.sortIndex = index
            for (index, target) in day.exercises.enumerated() {
                let exercise = context.entries.first { $0.exercise.id == target.exerciseID }!.exercise
                target.sortIndex = index
                target.targetSets = PlanRuleMath.initialSets
                target.minimumReps = exercise.minimumReps
                target.maximumReps = exercise.maximumReps
                target.targetWeightKg = nil
                // EN: Do not guess starting weights. Take repetition counts from the exercise list and calculate rest below.
                // VI: Không đoán mức tạ ban đầu. Lấy số lần lặp từ danh sách bài và tính thời gian nghỉ bên dưới.
                target.restSeconds = PlanRuleMath.rest(exercise, strategy: context.strategy)
            }
            day.estimatedMinutes = try PlanRuleMath.estimatedMinutes(day.exercises)
        }
        plan.goalRaw = context.request.goalID
        plan.targetWeightKg = context.goal == .loseFat ? context.request.targetWeightKg : nil
        plan.strategyRaw = context.strategy.rawValue
        let forecast = try PlanRuleMath.forecastWeeks(context.request)
        plan.forecastMinWeeks = forecast.min
        plan.forecastMaxWeeks = forecast.max
        plan.coachText = context.strategy.isConservative
            ? context.configuration.coachMessages.conservative
            : context.configuration.coachMessages.standard
    }

    /// EN: Check the plan without changing it. Use the same checks for rules and AI.
    /// VI: Kiểm tra plan mà không sửa nó. Lịch do rule và AI tạo đều qua cùng các kiểm tra.
    func validate(_ plan: TrainingPlan, request: PlanRequest, catalogue: [Exercise]) throws(CreatePersonalisedPlanError) {
        try validate(plan, context: prepare(request, catalogue: catalogue))
    }

    func milestones(for goalID: String) -> [String] {
        PlanRuleConfiguration.bundled?.milestones[goalID] ?? []
    }
}
