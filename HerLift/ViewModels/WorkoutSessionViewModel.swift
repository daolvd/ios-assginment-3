import Foundation
import Observation

/// Doing one workout: where she is, what she types for the set, and moving to the next set.
@MainActor
@Observable
final class WorkoutSessionViewModel {
    let workout: PlannedWorkout
    private(set) var log: WorkoutLog?
    var weightText = ""
    var repsText = ""
    var effort = PerceivedEffort.good
    /// Why a set or the workout could not be saved; shown as an alert.
    var error: WorkoutSessionError?
    @ObservationIgnored private let useCase: WorkoutSessionUseCase
    @ObservationIgnored private let now: () -> Date

    init(workout: PlannedWorkout, useCase: WorkoutSessionUseCase, now: @escaping () -> Date = { Date() }) {
        self.workout = workout
        self.useCase = useCase
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
    var hasLoggedSets: Bool { !(log?.sets.isEmpty ?? true) }

    var buttonTitle: String {
        if isFinished { return "Workout done" }
        return hasLoggedSets ? "Resume workout" : "Start workout"
    }

    /// Starts today's workout, or picks up the one in progress. Returns false when it could not be started.
    @discardableResult
    func start() -> Bool {
        do {
            log = try useCase.start(workout, on: now())
            prepareInputs()
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
        guard let last = lastSet(of: current) else { return "Find your weight × \(reps)" }
        return "Target \(Self.text(last.weightKg)) kg × \(reps)"
    }

    var cue: String? { current?.exercise.coachingCues.first }

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
        } catch {
            self.error = error
        }
    }

    /// Finishes the workout. Returns true once it is saved as done.
    func finish() -> Bool {
        guard let log else { return false }
        do {
            self.log = try useCase.finish(log)
            return true
        } catch {
            self.error = error
            return false
        }
    }

    // MARK: Helpers

    /// Starts each set with the weight of the exercise's last set and the top of its rep range.
    private func prepareInputs() {
        guard let current else {
            weightText = ""
            repsText = ""
            return
        }
        weightText = lastSet(of: current).map { Self.text($0.weightKg) } ?? ""
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
