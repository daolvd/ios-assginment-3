import Foundation

/// A suggested weight for the next set of the same exercise, worked out from the set she just did.
/// It only changes today's next set; it is never saved to the plan.
nonisolated struct NextSetSuggestion: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        /// She rated the set too hard.
        case tooHard
        /// She did fewer reps than the lowest in the plan.
        case belowTarget(minimumReps: Int)
        /// She rated the set easy and reached the highest reps.
        case easy
    }

    let kind: Kind
    let currentKg: Double
    let suggestedKg: Double

    /// The weight step of an exercise: 2.5 kg on machines and cables, 1 kg for dumbbells; none for bodyweight.
    static func incrementKg(for exercise: Exercise) -> Double? {
        switch exercise.equipment {
        case "machine", "cable": 2.5
        case "dumbbell": 1
        default: nil
        }
    }

    /// One step lighter after a set that was too hard or short of reps, one step heavier after an easy set at the
    /// top of the rep range, otherwise nothing. Bodyweight exercises and weights that would drop to zero get none.
    static func after(_ set: LoggedSet, of exercise: Exercise) -> NextSetSuggestion? {
        guard set.weightKg > 0, let step = incrementKg(for: exercise) else { return nil }

        if set.effort == .tooHard {
            return lighter(.tooHard, from: set.weightKg, step: step)
        }
        if set.repetitions < exercise.minimumReps {
            return lighter(.belowTarget(minimumReps: exercise.minimumReps), from: set.weightKg, step: step)
        }
        if set.effort == .easy, set.repetitions >= exercise.maximumReps {
            return NextSetSuggestion(kind: .easy, currentKg: set.weightKg, suggestedKg: set.weightKg + step)
        }
        return nil
    }

    var message: String {
        let weight = Self.text(suggestedKg)
        switch kind {
        case .tooHard:
            return "That was hard — try \(weight) kg for the next set. This only changes today."
        case .belowTarget(let minimumReps):
            return "You didn't reach \(minimumReps) reps — try \(weight) kg for the next set. This only changes today."
        case .easy:
            return "That felt easy — try \(weight) kg for the next set. This only changes today."
        }
    }

    var useTitle: String { "Use \(Self.text(suggestedKg)) kg" }
    var keepTitle: String { "Keep \(Self.text(currentKg)) kg" }

    private static func lighter(_ kind: Kind, from weight: Double, step: Double) -> NextSetSuggestion? {
        guard weight - step > 0 else { return nil }
        return NextSetSuggestion(kind: kind, currentKg: weight, suggestedKg: weight - step)
    }

    static func text(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(value)
    }
}
