import Foundation

@MainActor
extension PlanRuleEngine {
    private static let maximumScheduleAttempts = 20
    private static let desiredMajorMuscleSets = 4
    private static let desiredMajorMuscleExposures = 2

    private enum Score {
        static let preferredMuscle = 20_000
        static let missingMovement = 10_000
        static let setDeficit = 1_000
        static let dayBalance = 100
        static let candidateOverlap = 20
        static let familiarExercise = 10
        static let majorCoverage = 100
        static let exposureCoverage = 20
        static let layoutOverlap = 10
        static let guidedEquipment = 30
        static let seated = 5
        static let compound = 10
        static let coreLast = 10
    }

    func selectSchedule(context: Context) throws(CreatePersonalisedPlanError) -> [DaySelection] {
        let selected = context.request.trainingWeekdays.sorted()
        let schedules = selected.count == 7 ? (1...7).reversed().map { off in selected.filter { $0 != off } } : [selected]
        var best: (days: [DaySelection], score: Int)?
        for attempt in 0..<Self.maximumScheduleAttempts {
            let weekdays = schedules[attempt % schedules.count]
            guard let days = compose(weekdays, phase: attempt / schedules.count, context: context),
                  requiredMovements.isSubset(of: Set(days.flatMap(\.entries).map(\.movement))) else { continue }
            let score = layoutScore(days, context: context)
            if best == nil || score < best!.score || (score == best!.score && !weekdays.contains(7) && best!.days.contains { $0.weekday == 7 }) {
                best = (days, score)
            }
        }
        guard let best else { throw .invalidTrainingPlan }
        return best.days
    }

    func compose(_ weekdays: [Int], phase: Int, context: Context) -> [DaySelection]? {
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
        while days.flatMap(\.entries).count * PlanRuleMath.initialSets < context.volume.desiredSets {
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

    func canAdd(_ entry: Entry, to index: Int, days: [DaySelection], context: Context) -> Bool {
        let all = days.flatMap(\.entries), day = days[index]
        guard !day.entries.contains(where: { $0.exercise.id == entry.exercise.id }),
              (all.count + 1) * PlanRuleMath.initialSets <= context.volume.maximumSets,
              !entry.major || (all.filter { $0.muscle == entry.muscle }.count + 1) * PlanRuleMath.initialSets <= context.volume.maximumMajorMuscleSets else { return false }
        guard !days.filter({ PlanRuleMath.adjacent($0.weekday, day.weekday) }).flatMap(\.entries).contains(where: { $0.muscle == entry.muscle }) else { return false }
        let seconds = PlanRuleMath.sessionSeconds((day.entries + [entry]).map {
            (sets: PlanRuleMath.initialSets, rest: PlanRuleMath.rest($0.exercise, strategy: context.strategy))
        })
        return seconds <= context.request.sessionMinutes * 60
    }

    func candidateScore(_ entry: Entry, at index: Int, days: [DaySelection], context: Context, preferred: MuscleGroup?) -> Int {
        let all = days.flatMap(\.entries)
        let sets = all.filter { $0.muscle == entry.muscle }.count * PlanRuleMath.initialSets
        let missing = requiredMovements.contains(entry.movement) && !all.contains { $0.movement == entry.movement }
        let deficit = entry.major ? max(0, Self.desiredMajorMuscleSets - sets) : (sets == 0 ? 1 : 0)
        let neighbours = days.filter { PlanRuleMath.adjacent($0.weekday, days[index].weekday) }.flatMap(\.entries)
        let muscles = entry.secondary.union([entry.muscle])
        let overlap = neighbours.reduce(0) { $0 + muscles.intersection($1.secondary.union([$1.muscle])).count }
        return (preferred == entry.muscle ? Score.preferredMuscle : 0) + (missing ? Score.missingMovement : 0) + deficit * Score.setDeficit
            - days[index].entries.count * Score.dayBalance - overlap * Score.candidateOverlap + orderPriority(entry, context: context)
            + (context.goal == .increaseGymConfidence && all.contains { $0.exercise.id == entry.exercise.id } ? Score.familiarExercise : 0)
    }

    func layoutScore(_ days: [DaySelection], context: Context) -> Int {
        let all = days.flatMap(\.entries)
        let coverage = majorMuscles.reduce(0) { score, muscle in
            score + max(0, Self.desiredMajorMuscleSets - all.filter { $0.muscle == muscle }.count * PlanRuleMath.initialSets) * Score.majorCoverage
                + max(0, Self.desiredMajorMuscleExposures - days.filter { $0.entries.contains { $0.muscle == muscle } }.count) * Score.exposureCoverage
        }
        let overlap = days.reduce(0) { score, day in
            let muscles = Set(day.entries.flatMap { $0.secondary.union([$0.muscle]) })
            let next = days.first { $0.weekday == day.weekday % 7 + 1 }
            return score + muscles.intersection(Set(next?.entries.flatMap { $0.secondary.union([$0.muscle]) } ?? [])).count
        }
        return coverage + overlap * Score.layoutOverlap + max(0, context.volume.desiredSets - all.count * PlanRuleMath.initialSets)
    }

    func orderPriority(_ entry: Entry, context: Context) -> Int {
        let machines = context.goal == .increaseGymConfidence || context.strategy.prefersMachineFirst
        return (machines && entry.machine ? Score.guidedEquipment : 0) + (context.strategy.isLowImpact && ExercisePosition(rawValue: entry.exercise.position) == .seated ? Score.seated : 0)
            + (entry.compound ? Score.compound : 0) - (entry.movement == .core ? Score.coreLast : 0)
    }
}
