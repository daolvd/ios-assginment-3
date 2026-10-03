import Foundation
import Observation

/// Doing one workout: where she is, what she types for the set, resting between sets and moving to the next set.
@MainActor
@Observable
final class WorkoutSessionViewModel {
    /// The pause after a set, until the next one.
    struct RestState: Equatable {
        var endsAt: Date
        let next: WorkoutStep
        /// A weight for the next set, until she uses it or keeps hers.
        var suggestion: NextSetSuggestion?
    }

    enum ProposalDecision: Equatable {
        case applied
        case kept
    }

    let workout: PlannedWorkout
    private(set) var log: WorkoutLog?
    private(set) var rest: RestState?
    /// What the finished workout means for the plan; nil until the workout is finished.
    private(set) var summary: WorkoutSummary?
    private(set) var decisions: [Exercise.ID: ProposalDecision] = [:]
    var weightText = ""
    var repsText = ""
    var effort = PerceivedEffort.good
    /// Why a set or the workout could not be saved; shown as an alert.
    var error: WorkoutSessionError?
    /// The weight the next set aims for: the last set's weight, or the one she took from a suggestion.
    private var targetKg: Double?
    @ObservationIgnored private let useCase: WorkoutSessionUseCase
    @ObservationIgnored private let editPlan: EditWorkoutPlanUseCase
    @ObservationIgnored private let now: () -> Date
    /// Runs after the workout's state changed, so the widget can follow.
    @ObservationIgnored var onChange: () -> Void = {}

    init(
        workout: PlannedWorkout, useCase: WorkoutSessionUseCase, editPlan: EditWorkoutPlanUseCase,
        now: @escaping () -> Date = { Date() }
    ) {
        self.workout = workout
        self.useCase = useCase
        self.editPlan = editPlan
        self.now = now
    }

    /// Reads today's log, so a workout left half-done can be resumed.
    func load() {
        do {
            log = try useCase.currentLog(on: now())
            prepareInputs()
        } catch {
            self.error = error
        }
    }

    var isFinished: Bool { log?.status == .completed }
    /// The workout has been started and not finished.
    var isInProgress: Bool { log?.status == .inProgress }
    var hasLoggedSets: Bool { !(log?.sets.isEmpty ?? true) }

    var buttonTitle: String {
        if isFinished { return "Workout done" }
        return hasLoggedSets ? "Resume workout" : "Start workout"
    }

    /// Starts today's workout, or picks up the one in progress. `date` is when she started, if not now, such as
    /// on the widget. Returns false when it could not be started.
    @discardableResult
    func start(at date: Date? = nil) -> Bool {
        do {
            log = try useCase.start(workout, on: date ?? now())
            prepareInputs()
            onChange()
            return true
        } catch {
            self.error = error
            return false
        }
    }

    // MARK: Where she is

    var step: WorkoutStep? { log.flatMap { workout.nextStep(after: $0) } }
    var current: WorkoutExercise? { step.map { workout.exercises[$0.exerciseIndex] } }
    var isReadyToFinish: Bool { log?.status == .inProgress && step == nil }
    var showsWeightField: Bool { current?.exercise.loadType != "bodyweight" }

    /// "Exercise 1 of 3 · Set 2 of 5"
    var progressLine: String? {
        guard let step, let current else { return nil }
        return "Exercise \(step.exerciseIndex + 1) of \(workout.exercises.count) · Set \(step.setNumber) of \(current.sets)"
    }

    /// "Target 30 kg × 10–12", or "Find your weight × 10–12" until a first set shows the weight.
    var targetLine: String? {
        guard let current else { return nil }
        let reps = "\(current.exercise.minimumReps)–\(current.exercise.maximumReps)"
        guard showsWeightField else { return "Bodyweight × \(reps)" }
        guard let targetKg else { return "Find your weight × \(reps)" }
        return "Target \(Self.text(targetKg)) kg × \(reps)"
    }

    var cue: String? { current?.exercise.coachingCues.first }

    /// Until a weight is known for the exercise, she is asked to find one: not too heavy, about fifteen reps.
    var weightHint: String? {
        guard current != nil, showsWeightField, targetKg == nil else { return nil }
        return "Pick a weight you could lift about 15 times."
    }

    // MARK: The set being typed

    private var weight: Double? {
        showsWeightField ? Double(weightText.replacingOccurrences(of: ",", with: ".")) : 0
    }
    private var repetitions: Int? { Int(repsText.trimmingCharacters(in: .whitespaces)) }

    /// Shown once something is typed that cannot be a set; typing nothing shows nothing.
    var repsMessage: WorkoutSessionError? {
        guard !repsText.isEmpty else { return nil }
        guard let repetitions, WorkoutSessionUseCase.repetitionRange.contains(repetitions) else {
            return .invalidRepetitionCount
        }
        return nil
    }

    var weightMessage: WorkoutSessionError? {
        guard showsWeightField, !weightText.isEmpty else { return nil }
        guard let weight, weight > 0, weight <= WorkoutSessionUseCase.maximumWeightKg else { return .invalidWeight }
        return nil
    }

    var canCompleteSet: Bool {
        guard log?.status == .inProgress, step != nil, let weight, let repetitions else { return false }
        let weightIsValid = !showsWeightField || (weight > 0 && weight <= WorkoutSessionUseCase.maximumWeightKg)
        return weightIsValid && WorkoutSessionUseCase.repetitionRange.contains(repetitions)
    }

    func completeSet() {
        guard canCompleteSet, let log, let step, let current, let weight, let repetitions else { return }
        let set = LoggedSet(
            exerciseID: current.id, setNumber: step.setNumber, weightKg: weight, repetitions: repetitions, effort: effort)
        do {
            self.log = try useCase.record(set, in: log, of: workout)
            error = nil
            prepareInputs()
            startRest(after: set, of: current.exercise, from: step)
            onChange()
        } catch {
            self.error = error
        }
    }

    // MARK: Resting

    /// "Next: Lat Pulldown · Set 3 of 3"
    var restNextLine: String? {
        guard let rest else { return nil }
        let planned = workout.exercises[rest.next.exerciseIndex]
        return "Next: \(planned.exercise.name) · Set \(rest.next.setNumber) of \(planned.sets)"
    }

    /// Puts the suggested weight into the next set.
    func useSuggestion() {
        guard let suggestion = rest?.suggestion else { return }
        weightText = NextSetSuggestion.text(suggestion.suggestedKg)
        targetKg = suggestion.suggestedKg
        rest?.suggestion = nil
    }

    /// Keeps her own weight for the next set.
    func keepWeight() {
        rest?.suggestion = nil
    }

    func endRest() {
        rest = nil
        onChange()
    }

    /// Brings in what she did on the widget: the sets she finished, in order, and its rest. A set that is not the
    /// one she is on is left out, so a set already logged here is never logged twice. `restEndsAt` is when the
    /// widget's rest ends, or when she skipped it there; nil when the widget has no rest to report.
    func applyWidget(sets: [WidgetInbox.LoggedSet], restEndsAt: Date?) {
        for widgetSet in sets {
            guard let step, let current, current.id == widgetSet.exerciseID, step.setNumber == widgetSet.setNumber
            else { continue }
            weightText = Self.text(widgetSet.weightKg)
            repsText = String(widgetSet.repetitions)
            effort = PerceivedEffort(rawValue: widgetSet.effort) ?? .good
            completeSet()
        }
        guard let restEndsAt else { return }
        if restEndsAt > now(), rest != nil {
            rest?.endsAt = restEndsAt
        } else {
            rest = nil
        }
        onChange()
    }

    /// Rests for as long as the exercise says. There is no rest after the last set, and a suggestion is only made
    /// when the next set is of the same exercise.
    private func startRest(after set: LoggedSet, of exercise: Exercise, from step: WorkoutStep) {
        guard let next = self.step else {
            rest = nil
            return
        }
        let sameExercise = next.exerciseIndex == step.exerciseIndex
        rest = RestState(
            endsAt: now().addingTimeInterval(Double(exercise.defaultRestSeconds)), next: next,
            suggestion: sameExercise ? NextSetSuggestion.after(set, of: exercise) : nil)
    }

    /// Finishes the workout and works out what it means for the plan. Starting weights it showed are saved to the
    /// plan right away; the proposals wait for her. Returns true once the workout is saved as done.
    func finish() -> Bool {
        guard let log else { return false }
        do {
            let finished = try useCase.finish(log, at: now())
            self.log = finished
            rest = nil
            let summary = WorkoutFeedback.summary(of: workout, log: finished)
            self.summary = summary
            saveStartingWeights(summary.startingWeights)
            onChange()
            return true
        } catch {
            self.error = error
            return false
        }
    }

    // MARK: Proposals for next time

    var pendingProposals: [WeightProposal] {
        summary?.proposals.filter { decisions[$0.id] == nil } ?? []
    }

    func apply(_ proposal: WeightProposal) { applyAll([proposal]) }
    func applyAll() { applyAll(pendingProposals) }

    func keep(_ proposal: WeightProposal) { decisions[proposal.id] = .kept }

    func keepAll() {
        for proposal in pendingProposals { decisions[proposal.id] = .kept }
    }

    /// Changes the plan's target weights; the proposals are marked applied only once that is saved.
    private func applyAll(_ proposals: [WeightProposal]) {
        guard !proposals.isEmpty else { return }
        let changes = proposals.map { TargetWeightChange(weekday: $0.weekday, exerciseID: $0.exerciseID, weightKg: $0.proposedKg) }
        do {
            _ = try editPlan.setTargetWeights(changes)
            for proposal in proposals { decisions[proposal.id] = .applied }
            error = nil
        } catch {
            self.error = .couldNotUpdatePlan
        }
    }

    private func saveStartingWeights(_ startingWeights: [StartingWeight]) {
        guard !startingWeights.isEmpty else { return }
        let changes = startingWeights.map { TargetWeightChange(weekday: $0.weekday, exerciseID: $0.exerciseID, weightKg: $0.weightKg) }
        do { _ = try editPlan.setTargetWeights(changes) } catch { self.error = .couldNotUpdatePlan }
    }

    // MARK: Helpers

    /// Starts each set with the weight of the exercise's last set and the top of its rep range.
    private func prepareInputs() {
        guard let current else {
            targetKg = nil
            weightText = ""
            repsText = ""
            return
        }
        targetKg = lastSet(of: current)?.weightKg ?? current.targetWeightKg
        weightText = targetKg.map(Self.text) ?? ""
        repsText = String(current.exercise.maximumReps)
        effort = .good
    }

    private func lastSet(of planned: WorkoutExercise) -> LoggedSet? {
        log?.sets.last { $0.exerciseID == planned.id }
    }

    private static func text(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(value)
    }
}
