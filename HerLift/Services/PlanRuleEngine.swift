import Foundation

@MainActor
struct PlanRuleEngine {
    // MARK: Screening and catalogue

    private struct Context {
        let request: PlanRequest
        let strategy: TrainingStrategy
        let volume: WeeklyVolumePolicy
        let entries: [Entry]
    }

    private struct Entry {
        let exercise: Exercise
        let muscle: String
        let movement: String
        let compound: Bool
        var machine: Bool { ["machine", "cable"].contains(exercise.equipment) }
        var major: Bool { !["arms", "calves", "core"].contains(muscle) }
        var secondary: Set<String> { Set(exercise.secondaryMuscles.compactMap(PlanRuleEngine.muscle)) }
    }

    private struct DaySelection {
        let weekday: Int
        var entries: [Entry] = []
    }

    private let majorMuscles = ["quads", "chest", "hamstrings", "back", "glutes", "shoulders"]
    private let requiredMovements: Set<String> = ["knee", "hip", "push", "pull"]

    func eligibleExercises(for request: PlanRequest, catalogue: [Exercise]) throws(CreatePersonalisedPlanError) -> [Exercise] {
        try prepare(request, catalogue: catalogue).entries.map(\.exercise)
    }

    private func prepare(_ request: PlanRequest, catalogue: [Exercise]) throws(CreatePersonalisedPlanError) -> Context {
        guard request.age > 0, let bmi = bmi(request.weightKg, request.heightCm) else { throw .invalidTrainingPlan }
        let weekdays = Set(request.trainingWeekdays)
        guard (2...7).contains(weekdays.count), weekdays.count == request.trainingWeekdays.count,
              weekdays.allSatisfy({ (1...7).contains($0) }) else { throw .unsupportedTrainingFrequency }
        guard (30...120).contains(request.sessionMinutes), request.sessionMinutes.isMultiple(of: 5) else { throw .invalidSessionDuration }
        guard ["loseFat", "buildMuscle", "buildStrength", "increaseGymConfidence"].contains(request.goalID) else { throw .missingGoal }
        if request.goalID == "loseFat" {
            guard bmi >= 18.5, let target = request.targetWeightKg, target < request.weightKg,
                  let targetBMI = self.bmi(target, request.heightCm), targetBMI >= 18.5 else { throw .unsafeTargetWeight }
        }
        let profile = OnboardingProfile(age: request.age, heightCm: request.heightCm, weightKg: request.weightKg,
            experience: request.experience, trainingWeekdays: request.trainingWeekdays, sessionMinutes: request.sessionMinutes,
            healthNote: request.healthNote, clearedByDoctor: request.clearedByDoctor)
        guard case let .ready(strategy) = TrainingStrategyRule().evaluate(profile) else { throw .medicalClearanceRequired }
        guard Set(catalogue.map(\.id)).count == catalogue.count else { throw .noSuitableExercises }
        let entries = catalogue.compactMap { exercise -> Entry? in
            guard let role = Self.roles[exercise.id], allowed(exercise, request: request, strategy: strategy) else { return nil }
            return Entry(exercise: exercise, muscle: role.0, movement: role.1, compound: role.2)
        }.sorted { $0.exercise.id < $1.exercise.id }
        guard requiredMovements.isSubset(of: Set(entries.map(\.movement))) else { throw .noSuitableExercises }
        return Context(request: request, strategy: strategy, volume: WeeklyVolumePolicy(profile: profile, strategy: strategy), entries: entries)
    }

    private func allowed(_ exercise: Exercise, request: PlanRequest, strategy: TrainingStrategy) -> Bool {
        (exercise.level == "beginner" || (request.experience == .some && exercise.level == "intermediate"))
            && exercise.minimumReps > 0 && exercise.maximumReps >= exercise.minimumReps && exercise.maximumReps <= 100
            && (1...600).contains(exercise.defaultRestSeconds)
            && (!strategy.requiresGuidedEquipment || ["machine", "cable"].contains(exercise.equipment))
            && (!strategy.isLowImpact || (exercise.impact == "low" && !["floor", "kneeling"].contains(exercise.position)))
    }

    // MARK: Rule-based scheduling

    func generate(_ request: PlanRequest, catalogue: [Exercise]) throws(CreatePersonalisedPlanError) -> TrainingPlan {
        let context = try prepare(request, catalogue: catalogue)
        let selected = request.trainingWeekdays.sorted()
        let schedules = selected.count == 7 ? (1...7).reversed().map { off in selected.filter { $0 != off } } : [selected]
        var best: (days: [DaySelection], score: Int)?
        for attempt in 0..<20 {
            let weekdays = schedules[attempt % schedules.count]
            guard let days = compose(weekdays, phase: attempt / schedules.count, context: context),
                  requiredMovements.isSubset(of: Set(days.flatMap(\.entries).map(\.movement))) else { continue }
            let score = layoutScore(days, context: context)
            if best == nil || score < best!.score || (score == best!.score && !weekdays.contains(7) && best!.days.contains { $0.weekday == 7 }) {
                best = (days, score)
            }
        }
        guard let best else { throw .invalidTrainingPlan }
        let profile = UserProfile(age: request.age, heightCm: request.heightCm, weightKg: request.weightKg,
            experienceRaw: request.experience.rawValue, trainingWeekdays: selected, sessionMinutes: request.sessionMinutes,
            healthNote: request.healthNote, clearedByDoctor: request.clearedByDoctor)
        let plan = TrainingPlan(profile: profile, goalRaw: request.goalID, strategyRaw: context.strategy.rawValue,
                                generatorRaw: "ruleBased", coachText: "")
        plan.days = best.days.enumerated().map { index, selection in
            let day = WorkoutDay(plan: plan, sortIndex: index, weekday: selection.weekday, title: title(selection.entries), estimatedMinutes: 0)
            let ordered = selection.entries.sorted {
                let a = orderPriority($0, context: context), b = orderPriority($1, context: context)
                return a != b ? a > b : $0.exercise.id < $1.exercise.id
            }
            day.exercises = ordered.enumerated().map { index, entry in
                PlannedExercise(workoutDay: day, sortIndex: index, exerciseID: entry.exercise.id,
                    targetSets: 2, minimumReps: entry.exercise.minimumReps, maximumReps: entry.exercise.maximumReps,
                    restSeconds: rest(entry.exercise, strategy: context.strategy))
            }
            return day
        }
        try applyRules(to: plan, context: context)
        try validate(plan, context: context)
        return plan
    }

    private func compose(_ weekdays: [Int], phase: Int, context: Context) -> [DaySelection]? {
        var days = weekdays.map { DaySelection(weekday: $0) }
        let order = phase.isMultiple(of: 2) ? Array(days.indices) : Array(days.indices.reversed())
        for (position, index) in order.enumerated() {
            let preferred = majorMuscles[(position + phase) % majorMuscles.count]
            let candidates = context.entries.filter { canAdd($0, to: index, days: days, context: context) }
            guard let entry = candidates.max(by: {
                let a = candidateScore($0, at: index, days: days, context: context, preferred: preferred)
                let b = candidateScore($1, at: index, days: days, context: context, preferred: preferred)
                return a != b ? a < b : $0.exercise.id > $1.exercise.id
            }) else { return nil }
            days[index].entries.append(entry)
        }
        while days.flatMap(\.entries).count * 2 < context.volume.desiredSets {
            var best: (day: Int, entry: Entry, score: Int)?
            for index in days.indices {
                for entry in context.entries where canAdd(entry, to: index, days: days, context: context) {
                    let score = candidateScore(entry, at: index, days: days, context: context, preferred: nil)
                    if best == nil || score > best!.score { best = (index, entry, score) }
                }
            }
            guard let best else { break }
            days[best.day].entries.append(best.entry)
        }
        return days
    }

    private func canAdd(_ entry: Entry, to index: Int, days: [DaySelection], context: Context) -> Bool {
        let all = days.flatMap(\.entries), day = days[index]
        guard !day.entries.contains(where: { $0.exercise.id == entry.exercise.id }),
              (all.count + 1) * 2 <= context.volume.maximumSets,
              !entry.major || (all.filter { $0.muscle == entry.muscle }.count + 1) * 2 <= context.volume.maximumMajorMuscleSets else { return false }
        guard !days.filter({ adjacent($0.weekday, day.weekday) }).flatMap(\.entries).contains(where: { $0.muscle == entry.muscle }) else { return false }
        let seconds = 300 + (day.entries + [entry]).reduce(0) { $0 + 90 + rest($1.exercise, strategy: context.strategy) } + day.entries.count * 60
        return seconds <= context.request.sessionMinutes * 60
    }

    private func candidateScore(_ entry: Entry, at index: Int, days: [DaySelection], context: Context, preferred: String?) -> Int {
        let all = days.flatMap(\.entries)
        let sets = all.filter { $0.muscle == entry.muscle }.count * 2
        let missing = requiredMovements.contains(entry.movement) && !all.contains { $0.movement == entry.movement }
        let deficit = entry.major ? max(0, 4 - sets) : (sets == 0 ? 1 : 0)
        let neighbours = days.filter { adjacent($0.weekday, days[index].weekday) }.flatMap(\.entries)
        let muscles = entry.secondary.union([entry.muscle])
        let overlap = neighbours.reduce(0) { $0 + muscles.intersection($1.secondary.union([$1.muscle])).count }
        return (preferred == entry.muscle ? 20_000 : 0) + (missing ? 10_000 : 0) + deficit * 1000
            - days[index].entries.count * 100 - overlap * 20 + orderPriority(entry, context: context)
            + (context.request.goalID == "increaseGymConfidence" && all.contains { $0.exercise.id == entry.exercise.id } ? 10 : 0)
    }

    private func layoutScore(_ days: [DaySelection], context: Context) -> Int {
        let all = days.flatMap(\.entries)
        let coverage = majorMuscles.reduce(0) { score, muscle in
            score + max(0, 4 - all.filter { $0.muscle == muscle }.count * 2) * 100
                + max(0, 2 - days.filter { $0.entries.contains { $0.muscle == muscle } }.count) * 20
        }
        let overlap = days.reduce(0) { score, day in
            let muscles = Set(day.entries.flatMap { $0.secondary.union([$0.muscle]) })
            let next = days.first { $0.weekday == day.weekday % 7 + 1 }
            return score + muscles.intersection(Set(next?.entries.flatMap { $0.secondary.union([$0.muscle]) } ?? [])).count
        }
        return coverage + overlap * 10 + max(0, context.volume.desiredSets - all.count * 2)
    }

    // MARK: Targets, duration and metadata for either scheduler

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
                target.targetSets = 2
                target.minimumReps = exercise.minimumReps
                target.maximumReps = exercise.maximumReps
                target.targetWeightKg = nil
                target.restSeconds = rest(exercise, strategy: context.strategy)
            }
            day.estimatedMinutes = try estimatedMinutes(day.exercises)
        }
        plan.goalRaw = context.request.goalID
        plan.targetWeightKg = context.request.goalID == "loseFat" ? context.request.targetWeightKg : nil
        plan.strategyRaw = context.strategy.rawValue
        let forecast = try forecastWeeks(context.request)
        plan.forecastMinWeeks = forecast.min
        plan.forecastMaxWeeks = forecast.max
        plan.coachText = context.strategy.isConservative
            ? "Start gently. Find comfortable starting weights and keep your effort at Good during your first two weeks."
            : "Practise your technique and find comfortable starting weights. Changes to your weights need your approval."
    }

    private func estimatedMinutes(_ exercises: [PlannedExercise]) throws(CreatePersonalisedPlanError) -> Int {
        guard !exercises.isEmpty, exercises.count <= 32,
              exercises.allSatisfy({ (1...3).contains($0.targetSets) && (1...630).contains($0.restSeconds) }) else { throw .invalidTrainingPlan }
        let seconds = 300 + exercises.reduce(0) { $0 + $1.targetSets * 45 + ($1.targetSets - 1) * $1.restSeconds } + (exercises.count - 1) * 60
        return (seconds + 59) / 60
    }

    // MARK: Shared validation

    func validate(_ plan: TrainingPlan, request: PlanRequest, catalogue: [Exercise]) throws(CreatePersonalisedPlanError) {
        try validate(plan, context: prepare(request, catalogue: catalogue))
    }

    private func validate(_ plan: TrainingPlan, context: Context) throws(CreatePersonalisedPlanError) {
        let request = context.request, days = plan.days
        let selected = Set(request.trainingWeekdays), actual = Set(days.map(\.weekday))
        guard actual.count == days.count, actual.count == min(selected.count, 6), actual.isSubset(of: selected),
              days.map(\.sortIndex).sorted() == Array(days.indices), plan.goalRaw == request.goalID,
              plan.strategyRaw == context.strategy.rawValue, plan.targetWeeks == 12,
              ["ruleBased", "onDeviceAI"].contains(plan.generatorRaw),
              plan.profile.age == request.age, plan.profile.heightCm == request.heightCm, plan.profile.weightKg == request.weightKg,
              plan.profile.experienceRaw == request.experience.rawValue,
              plan.profile.trainingWeekdays.sorted() == request.trainingWeekdays.sorted(),
              plan.profile.sessionMinutes == request.sessionMinutes, plan.profile.healthNote == request.healthNote,
              plan.profile.clearedByDoctor == request.clearedByDoctor,
              plan.targetWeightKg == (request.goalID == "loseFat" ? request.targetWeightKg : nil) else { throw .invalidTrainingPlan }
        var total = 0, direct: [String: Int] = [:], muscles: [Int: Set<String>] = [:], movements: Set<String> = []
        for day in days {
            guard day.plan.id == plan.id, !day.exercises.isEmpty,
                  Set(day.exercises.map(\.exerciseID)).count == day.exercises.count,
                  day.exercises.map(\.sortIndex).sorted() == Array(day.exercises.indices) else { throw .invalidTrainingPlan }
            for target in day.exercises {
                guard let entry = context.entries.first(where: { $0.exercise.id == target.exerciseID }),
                      target.workoutDay.id == day.id, (1...context.strategy.maximumSetsPerExercise).contains(target.targetSets),
                      context.strategy.maximumSetsPerExercise != 2 || target.targetSets == 2,
                      target.minimumReps == entry.exercise.minimumReps, target.maximumReps == entry.exercise.maximumReps,
                      target.restSeconds == rest(entry.exercise, strategy: context.strategy), target.targetWeightKg == nil else { throw .invalidTrainingPlan }
                total += target.targetSets
                direct[entry.muscle, default: 0] += target.targetSets
                muscles[day.weekday, default: []].insert(entry.muscle)
                movements.insert(entry.movement)
            }
            guard day.estimatedMinutes == (try estimatedMinutes(day.exercises)), day.estimatedMinutes <= request.sessionMinutes else { throw .invalidTrainingPlan }
        }
        guard total <= context.volume.maximumSets, requiredMovements.isSubset(of: movements),
              majorMuscles.allSatisfy({ direct[$0, default: 0] <= context.volume.maximumMajorMuscleSets }) else { throw .invalidTrainingPlan }
        for (weekday, primary) in muscles {
            guard primary.isDisjoint(with: muscles[weekday % 7 + 1, default: []]) else { throw .invalidTrainingPlan }
        }
        let forecast = try forecastWeeks(request)
        guard plan.forecastMinWeeks == forecast.min, plan.forecastMaxWeeks == forecast.max else { throw .invalidTrainingPlan }
    }

    // MARK: Forecast and catalogue roles

    func milestones(for goalID: String) -> [String] {
        switch goalID {
        case "buildMuscle", "buildStrength":
            ["Weeks 1–2: learn technique and find starting weights.",
             "Weeks 3–6: progress gradually with changes you approve.",
             "Week 8: strength check.", "Week 12: review your goal."]
        case "increaseGymConfidence": ["Week 4: practise doing all your plan exercises on your own."]
        default: []
        }
    }

    private func forecastWeeks(_ request: PlanRequest) throws(CreatePersonalisedPlanError) -> (min: Int?, max: Int?) {
        guard request.goalID == "loseFat", let target = request.targetWeightKg else { return (nil, nil) }
        let difference = request.weightKg - target
        let maximum = ceil(difference / 0.5)
        guard maximum.isFinite, maximum < Double(Int.max) else { throw .invalidTrainingPlan }
        return (Int(ceil(difference)), Int(maximum))
    }

    private func bmi(_ weight: Double, _ height: Double) -> Double? {
        guard weight.isFinite, weight > 0, height.isFinite, height > 0 else { return nil }
        let result = weight * 10_000 / (height * height)
        return result.isFinite && result > 0 ? result : nil
    }

    private func rest(_ exercise: Exercise, strategy: TrainingStrategy) -> Int { exercise.defaultRestSeconds + (strategy.needsLongerRest ? 30 : 0) }
    private func adjacent(_ a: Int, _ b: Int) -> Bool { (a - b + 7) % 7 == 1 || (b - a + 7) % 7 == 1 }
    private func orderPriority(_ entry: Entry, context: Context) -> Int {
        let machines = context.request.goalID == "increaseGymConfidence" || context.strategy.prefersMachineFirst
        return (machines && entry.machine ? 30 : 0) + (context.strategy.isLowImpact && entry.exercise.position == "seated" ? 5 : 0)
            + (entry.compound ? 10 : 0) - (entry.movement == "core" ? 10 : 0)
    }
    private func title(_ entries: [Entry]) -> String {
        let groups = Set(entries.map(\.muscle)).subtracting(["core"])
        let lower: Set<String> = ["quads", "hamstrings", "glutes", "calves"]
        if groups.isSubset(of: lower) { return "Lower body" }
        if groups.isDisjoint(with: lower) { return "Upper body" }
        return "Full body"
    }

    private static func muscle(_ name: String) -> String? {
        switch name.lowercased() {
        case "quads", "quadriceps", "adductors": "quads"
        case "hamstrings": "hamstrings"
        case "glutes", "gluteus maximus", "glute medius": "glutes"
        case "chest", "upper chest", "pectoralis major": "chest"
        case "lats", "mid back", "upper back", "lower back", "erector spinae", "traps", "trapezius", "rhomboids", "middle trapezius": "back"
        case "front delts", "side delts", "rear delts", "shoulders", "rear deltoids", "posterior deltoids", "anterior deltoids": "shoulders"
        case "biceps", "biceps brachii", "triceps", "triceps brachii", "anconeus", "forearms": "arms"
        case "calves", "soleus": "calves"
        case "abs", "lower abs", "obliques": "core"
        default: nil
        }
    }

    private static let roles: [String: (String, String, Bool)] = [
        "leg-press": ("quads", "knee", true), "goblet-squat": ("quads", "knee", true), "leg-extension": ("quads", "accessory", false),
        "romanian-deadlift": ("hamstrings", "hip", true), "seated-leg-curl": ("hamstrings", "accessory", false),
        "standing-calf-raise": ("calves", "accessory", false), "glute-bridge": ("glutes", "hip", true),
        "glute-kickback": ("glutes", "hip", false), "hip-abduction": ("glutes", "accessory", false),
        "lat-pulldown": ("back", "pull", true), "seated-cable-row": ("back", "pull", true), "chest-supported-row": ("back", "pull", true),
        "machine-chest-press": ("chest", "push", true), "seated-dumbbell-shoulder-press": ("shoulders", "push", true),
        "dumbbell-lateral-raise": ("shoulders", "accessory", false), "rope-rear-delt-row": ("shoulders", "accessory", false),
        "biceps-curl": ("arms", "accessory", false), "triceps-pushdown": ("arms", "accessory", false),
        "reverse-crunch": ("core", "core", false), "cable-kneeling-crunch": ("core", "core", false)
    ]
}
