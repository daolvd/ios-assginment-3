import Foundation

@MainActor
extension PlanRuleEngine {
    func prepare(_ request: PlanRequest, catalogue: [Exercise]) throws(CreatePersonalisedPlanError) -> Context {
        guard request.age > 0, let bmi = PlanRules.bmi(weightKg: request.weightKg, heightCm: request.heightCm) else { throw .invalidTrainingPlan }
        let weekdays = Set(request.trainingWeekdays)
        guard (2...7).contains(weekdays.count), weekdays.count == request.trainingWeekdays.count,
              weekdays.allSatisfy({ (1...7).contains($0) }) else { throw .unsupportedTrainingFrequency }
        guard (30...120).contains(request.sessionMinutes), request.sessionMinutes.isMultiple(of: 5) else { throw .invalidSessionDuration }
        guard let goal = PlanGoalKind(rawValue: request.goalID) else { throw .missingGoal }
        if goal == .loseFat {
            guard bmi >= 18.5, let target = request.targetWeightKg, target < request.weightKg,
                  let targetBMI = PlanRules.bmi(weightKg: target, heightCm: request.heightCm), targetBMI >= 18.5 else { throw .unsafeTargetWeight }
        }
        let profile = OnboardingProfile(age: request.age, heightCm: request.heightCm, weightKg: request.weightKg,
            experience: request.experience, trainingWeekdays: request.trainingWeekdays, sessionMinutes: request.sessionMinutes,
            healthNote: request.healthNote, clearedByDoctor: request.clearedByDoctor)
        guard case let .ready(strategy) = TrainingStrategyRule().evaluate(profile) else { throw .medicalClearanceRequired }
        guard Set(catalogue.map(\.id)).count == catalogue.count else { throw .noSuitableExercises }
        guard let configuration = PlanRuleConfiguration.bundled else { throw .invalidTrainingPlan }
        let entries = catalogue.compactMap { exercise -> Entry? in
            guard let role = configuration.exerciseRoles[exercise.id], allowed(exercise, request: request, strategy: strategy) else { return nil }
            return Entry(exercise: exercise, muscle: role.muscle, movement: role.movement, compound: role.compound,
                         secondary: Set(exercise.secondaryMuscles.compactMap { configuration.muscleAliases[$0.lowercased()] }))
        }.sorted { $0.exercise.id < $1.exercise.id }
        guard requiredMovements.isSubset(of: Set(entries.map(\.movement))) else { throw .noSuitableExercises }
        return Context(request: request, goal: goal, strategy: strategy, volume: WeeklyVolumePolicy(profile: profile, strategy: strategy), entries: entries, configuration: configuration)
    }

    func allowed(_ exercise: Exercise, request: PlanRequest, strategy: TrainingStrategy) -> Bool {
        (exercise.level == "beginner" || (request.experience == .some && exercise.level == "intermediate"))
            && exercise.minimumReps > 0 && exercise.maximumReps >= exercise.minimumReps && exercise.maximumReps <= 100
            && (1...600).contains(exercise.defaultRestSeconds)
            && (!strategy.requiresGuidedEquipment || GuidedEquipment(rawValue: exercise.equipment) != nil)
            && (!strategy.isLowImpact || (exercise.impact == "low" && ExercisePosition(rawValue: exercise.position)?.isFloorBased != true))
    }
}
