import Foundation

@MainActor
struct PlanRuleEngine {
    func eligibleExercises(for request: PlanRequest, catalogue: [Exercise]) throws(CreatePersonalisedPlanError) -> [Exercise] {
        try prepare(request, catalogue: catalogue).entries.map(\.exercise)
    }

    func generate(_ request: PlanRequest, catalogue: [Exercise]) throws(CreatePersonalisedPlanError) -> TrainingPlan {
        let context = try prepare(request, catalogue: catalogue)
        let selected = request.trainingWeekdays.sorted()
        let days = try selectSchedule(context: context)
        let profile = UserProfile(age: request.age, heightCm: request.heightCm, weightKg: request.weightKg,
            experienceRaw: request.experience.rawValue, trainingWeekdays: selected, sessionMinutes: request.sessionMinutes,
            healthNote: request.healthNote, clearedByDoctor: request.clearedByDoctor)
        let plan = TrainingPlan(profile: profile, goalRaw: request.goalID, strategyRaw: context.strategy.rawValue,
                                generatorRaw: PlanGeneratorKind.ruleBased.rawValue, coachText: "")
        plan.days = days.enumerated().map { index, selection in
            let day = WorkoutDay(plan: plan, sortIndex: index, weekday: selection.weekday, title: PlanRuleMath.title(selection.entries.map(\.muscle)), estimatedMinutes: 0)
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
        try applyRules(to: plan, context: context)
        try validate(plan, context: context)
        return plan
    }

    func applyRules(to plan: TrainingPlan, request: PlanRequest, catalogue: [Exercise]) throws(CreatePersonalisedPlanError) {
        try applyRules(to: plan, context: prepare(request, catalogue: catalogue))
        try validate(plan, request: request, catalogue: catalogue)
    }

    private func applyRules(to plan: TrainingPlan, context: Context) throws(CreatePersonalisedPlanError) {
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

    func validate(_ plan: TrainingPlan, request: PlanRequest, catalogue: [Exercise]) throws(CreatePersonalisedPlanError) {
        try validate(plan, context: prepare(request, catalogue: catalogue))
    }

    func milestones(for goalID: String) -> [String] {
        PlanRuleConfiguration.bundled?.milestones[goalID] ?? []
    }
}
