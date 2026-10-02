import Foundation

/// A weight she should find hard to lift again next time.
nonisolated struct WeightProposal: Equatable, Identifiable, Sendable {
    let weekday: Int
    let exerciseID: Exercise.ID
    let exerciseName: String
    let currentKg: Double
    let proposedKg: Double

    var id: Exercise.ID { exerciseID }

    /// "30 → 32.5 kg"
    var changeText: String {
        "\(NextSetSuggestion.text(currentKg)) → \(NextSetSuggestion.text(proposedKg)) kg"
    }
}

/// A starting weight a first workout showed for an exercise that had none.
nonisolated struct StartingWeight: Equatable, Identifiable, Sendable {
    let weekday: Int
    let exerciseID: Exercise.ID
    let exerciseName: String
    let weightKg: Double

    var id: Exercise.ID { exerciseID }
}

/// What a finished workout means for the plan. The proposals are only suggestions until she applies them.
nonisolated struct WorkoutSummary: Equatable, Sendable {
    let title: String
    /// From starting to finishing; nil when the times were not recorded.
    let minutes: Int?
    let setCount: Int
    let startingWeights: [StartingWeight]
    let proposals: [WeightProposal]
}

/// The rules that turn a finished workout into starting weights and proposals. One workout is the only evidence.
nonisolated enum WorkoutFeedback {
    static func summary(of workout: PlannedWorkout, log: WorkoutLog) -> WorkoutSummary {
        var startingWeights: [StartingWeight] = []
        var proposals: [WeightProposal] = []

        for planned in workout.exercises {
            let sets = log.sets.filter { $0.exerciseID == planned.id }
            guard !sets.isEmpty, planned.exercise.loadType != "bodyweight" else { continue }

            if let target = planned.targetWeightKg {
                if let proposed = proposedWeight(after: sets, of: planned, from: target) {
                    proposals.append(WeightProposal(
                        weekday: workout.weekday, exerciseID: planned.id, exerciseName: planned.exercise.name,
                        currentKg: target, proposedKg: proposed))
                }
            } else {
                startingWeights.append(StartingWeight(
                    weekday: workout.weekday, exerciseID: planned.id, exerciseName: planned.exercise.name,
                    weightKg: startingWeight(from: sets, of: planned.exercise)))
            }
        }

        return WorkoutSummary(
            title: workout.categoryIDs.map(\.capitalized).joined(separator: " · "),
            minutes: minutes(of: log), setCount: log.sets.count,
            startingWeights: startingWeights, proposals: proposals)
    }

    /// The heaviest set that reached the lowest reps and felt easy or good; if none did, the lightest set.
    private static func startingWeight(from sets: [LoggedSet], of exercise: Exercise) -> Double {
        let comfortable = sets.filter { $0.repetitions >= exercise.minimumReps && ($0.effort == .easy || $0.effort == .good) }
        if let heaviest = comfortable.map(\.weightKg).max() { return heaviest }
        return sets.map(\.weightKg).min() ?? 0
    }

    /// One step heavier when every planned set was done at the highest reps and felt easy or good; one step lighter
    /// when two or more sets were too hard or short of the lowest reps; otherwise no change.
    private static func proposedWeight(after sets: [LoggedSet], of planned: WorkoutExercise, from target: Double) -> Double? {
        guard let step = NextSetSuggestion.incrementKg(for: planned.exercise) else { return nil }

        let struggled = sets.filter { $0.effort == .tooHard || $0.repetitions < planned.exercise.minimumReps }
        if struggled.count >= 2 {
            return target - step > 0 ? target - step : nil
        }
        let doneEveryPlannedSet = (1...planned.sets).allSatisfy { number in sets.contains { $0.setNumber == number } }
        let allEasyAtTheTop = sets.allSatisfy {
            $0.repetitions >= planned.exercise.maximumReps && ($0.effort == .easy || $0.effort == .good)
        }
        return doneEveryPlannedSet && allEasyAtTheTop ? target + step : nil
    }

    private static func minutes(of log: WorkoutLog) -> Int? {
        guard let start = log.startedAt, let end = log.completedAt else { return nil }
        return max(1, Int((end.timeIntervalSince(start) / 60).rounded()))
    }
}
