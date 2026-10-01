import Foundation

@MainActor
extension PlanRuleEngine {
    /// EN: Check the answers and build the allowed exercise list before creating a plan.
    /// VI: Kiểm tra câu trả lời và tạo danh sách bài được phép trước khi tạo plan.
    func prepare(_ request: PlanRequest, catalogue: [Exercise]) throws(CreatePersonalisedPlanError) -> Context {
        // EN: Reject invalid body measurements, repeated/invalid days, or sessions outside 30–120 minutes.
        // VI: Từ chối số đo không hợp lệ, ngày trùng/sai, hoặc buổi tập ngoài 30–120 phút.
        guard request.age > 0, let bmi = PlanRules.bmi(weightKg: request.weightKg, heightCm: request.heightCm) else { throw .invalidTrainingPlan }
        let weekdays = Set(request.trainingWeekdays)
        guard (2...7).contains(weekdays.count), weekdays.count == request.trainingWeekdays.count,
              weekdays.allSatisfy({ (1...7).contains($0) }) else { throw .unsupportedTrainingFrequency }
        guard (30...120).contains(request.sessionMinutes), request.sessionMinutes.isMultiple(of: 5) else { throw .invalidSessionDuration }
        guard let goal = PlanGoalKind(rawValue: request.goalID) else { throw .missingGoal }
        if goal == .loseFat {
            // EN: For weight loss, both current and target BMI must be at least 18.5; the target weight must be lower.
            // VI: Khi giảm cân, BMI hiện tại và mục tiêu đều phải ít nhất 18.5; cân nặng mục tiêu phải thấp hơn.
            guard bmi >= 18.5, let target = request.targetWeightKg, target < request.weightKg,
                  let targetBMI = PlanRules.bmi(weightKg: target, heightCm: request.heightCm), targetBMI >= 18.5 else { throw .unsafeTargetWeight }
        }
        let profile = OnboardingProfile(age: request.age, heightCm: request.heightCm, weightKg: request.weightKg,
            experience: request.experience, trainingWeekdays: request.trainingWeekdays, sessionMinutes: request.sessionMinutes,
            healthNote: request.healthNote, clearedByDoctor: request.clearedByDoctor)
        guard case let .ready(strategy) = TrainingStrategyRule().evaluate(profile) else { throw .medicalClearanceRequired }
        // EN: Apply all relevant training limits together. Reject duplicate IDs because one ID must identify one exercise.
        // VI: Áp dụng cùng lúc các giới hạn liên quan. Loại ID trùng vì một ID phải xác định đúng một bài.
        guard Set(catalogue.map(\.id)).count == catalogue.count else { throw .noSuitableExercises }
        guard let configuration = PlanRuleConfiguration.bundled else { throw .invalidTrainingPlan }
        let entries = catalogue.compactMap { exercise -> Entry? in
            // EN: Keep only suitable exercises with known roles. Convert secondary-muscle names to the shared muscle groups.
            // VI: Chỉ giữ bài phù hợp và có vai trò đã khai báo. Đổi tên cơ phụ về nhóm cơ dùng chung.
            guard let role = configuration.exerciseRoles[exercise.id], allowed(exercise, request: request, strategy: strategy) else { return nil }
            return Entry(exercise: exercise, muscle: role.muscle, movement: role.movement, compound: role.compound,
                         secondary: Set(exercise.secondaryMuscles.compactMap { configuration.muscleAliases[$0.lowercased()] }))
        }.sorted { $0.exercise.id < $1.exercise.id }
        // EN: The remaining list must include knee, hip, push and pull movements.
        // VI: Danh sách còn lại phải có bài dùng gối, dùng hông, đẩy và kéo.
        // EN: Examples: knee = leg press, hip = glute bridge, push = chest press, pull = cable row.
        // VI: Ví dụ: knee = đạp đùi, hip = nâng hông, push = đẩy ngực, pull = kéo cáp.
        guard requiredMovements.isSubset(of: Set(entries.map(\.movement))) else { throw .noSuitableExercises }
        let minimumRest = entries.map { PlanRuleMath.rest($0.exercise, strategy: strategy) }.min()!
        let volume = WeeklyVolumePolicy(profile: profile, strategy: strategy,
                                       minimumRestSeconds: minimumRest, exerciseCount: entries.count)
        return Context(request: request, goal: goal, strategy: strategy, volume: volume, entries: entries, configuration: configuration)
    }

    /// EN: New users get beginner exercises; users with experience can also get intermediate exercises.
    /// VI: Người mới dùng bài beginner; người có kinh nghiệm được thêm bài intermediate.
    /// EN: Conservative means machine/cable only. Low impact means low-impact exercises without floor/kneeling positions.
    /// VI: Conservative chỉ dùng máy/cable. Low impact chỉ dùng bài ít tác động, không ở tư thế nằm sàn/quỳ.
    func allowed(_ exercise: Exercise, request: PlanRequest, strategy: TrainingStrategy) -> Bool {
        (exercise.level == "beginner" || (request.experience == .some && exercise.level == "intermediate"))
            && exercise.minimumReps > 0 && exercise.maximumReps >= exercise.minimumReps && exercise.maximumReps <= 100
            && (1...600).contains(exercise.defaultRestSeconds)
            && (!strategy.requiresGuidedEquipment || GuidedEquipment(rawValue: exercise.equipment) != nil)
            && (!strategy.isLowImpact || (exercise.impact == "low" && ExercisePosition(rawValue: exercise.position)?.isFloorBased != true))
    }
}
