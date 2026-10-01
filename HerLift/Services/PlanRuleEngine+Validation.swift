import Foundation

@MainActor
extension PlanRuleEngine {
    func validate(_ plan: TrainingPlan, context: Context) throws(CreatePersonalisedPlanError) {
        let request = context.request, days = plan.days
        try validateMetadata(plan, context: context)
        var total = 0, direct: [MuscleGroup: Int] = [:], muscles: [Int: Set<MuscleGroup>] = [:], movements: Set<MovementPattern> = []
        for day in days {
            guard day.plan.id == plan.id, !day.exercises.isEmpty,
                  Set(day.exercises.map(\.exerciseID)).count == day.exercises.count,
                  day.exercises.map(\.sortIndex).sorted() == Array(day.exercises.indices) else { throw .invalidTrainingPlan }
            for target in day.exercises {
                guard let entry = context.entries.first(where: { $0.exercise.id == target.exerciseID }),
                      target.workoutDay.id == day.id, (1...context.strategy.maximumSetsPerExercise).contains(target.targetSets),
                      context.strategy.maximumSetsPerExercise != 2 || target.targetSets == 2,
                      target.minimumReps == entry.exercise.minimumReps, target.maximumReps == entry.exercise.maximumReps,
                      target.restSeconds == PlanRuleMath.rest(entry.exercise, strategy: context.strategy), target.targetWeightKg == nil else { throw .invalidTrainingPlan }
                total += target.targetSets
                direct[entry.muscle, default: 0] += target.targetSets
                muscles[day.weekday, default: []].insert(entry.muscle)
                movements.insert(entry.movement)
            }
            guard day.estimatedMinutes == (try PlanRuleMath.estimatedMinutes(day.exercises)), day.estimatedMinutes <= request.sessionMinutes else { throw .invalidTrainingPlan }
        }
        guard total <= context.volume.maximumSets, requiredMovements.isSubset(of: movements),
              majorMuscles.allSatisfy({ direct[$0, default: 0] <= context.volume.maximumMajorMuscleSets }) else { throw .invalidTrainingPlan }
        for (weekday, primary) in muscles {
            guard primary.isDisjoint(with: muscles[weekday % 7 + 1, default: []]) else { throw .invalidTrainingPlan }
        }
        let forecast = try PlanRuleMath.forecastWeeks(request)
        guard plan.forecastMinWeeks == forecast.min, plan.forecastMaxWeeks == forecast.max else { throw .invalidTrainingPlan }
    }

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
