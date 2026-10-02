import Foundation

/// Everything about doing a workout: start it, log its sets, finish it. One workout per day, saved after every set,
/// so closing the app mid-workout loses nothing.
@MainActor
struct WorkoutSessionUseCase {
    static let repetitionRange = 1...100
    static let maximumWeightKg = 300.0

    let sessions: any WorkoutSessionRepository
    var calendar = Calendar.current

    /// Today's log: nil until the workout has been started.
    func currentLog(on date: Date) throws(WorkoutSessionError) -> WorkoutLog? {
        do { return try sessions.log(on: calendar.startOfDay(for: date)) } catch { throw .couldNotLoadWorkouts }
    }

    /// Starts today's workout, or returns the one already in progress.
    func start(_ workout: PlannedWorkout, on date: Date) throws(WorkoutSessionError) -> WorkoutLog {
        let day = calendar.startOfDay(for: date)
        guard workout.weekday == PlanWeek.mondayBasedWeekday(of: day, calendar: calendar) else { throw .notToday }
        if let existing = try currentLog(on: day) {
            guard existing.status == .inProgress else { throw .alreadyCompleted }
            return existing
        }
        let log = WorkoutLog(date: day, weekday: workout.weekday, status: .inProgress, sets: [])
        do { try sessions.save(log) } catch { throw .couldNotStartWorkout }
        return log
    }

    /// Adds one set to the log and saves it.
    func record(_ set: LoggedSet, in log: WorkoutLog, of workout: PlannedWorkout) throws(WorkoutSessionError)
        -> WorkoutLog
    {
        guard log.status == .inProgress else { throw .workoutNotActive }
        guard let planned = workout.exercises.first(where: { $0.id == set.exerciseID }) else {
            throw .exerciseNotInWorkout
        }
        guard Self.repetitionRange.contains(set.repetitions) else { throw .invalidRepetitionCount }
        guard isValidWeight(set.weightKg, for: planned.exercise) else { throw .invalidWeight }
        guard set.setNumber >= 1, set.setNumber <= planned.sets else { throw .allSetsCompleted }
        guard !log.sets.contains(where: { $0.exerciseID == set.exerciseID && $0.setNumber == set.setNumber }) else {
            throw .duplicateSet
        }

        var updated = log
        updated.sets.append(set)
        do { try sessions.save(updated) } catch { throw .couldNotSaveSet }
        return updated
    }

    /// Finishes the workout. She can finish early, but not before logging at least one set.
    func finish(_ log: WorkoutLog) throws(WorkoutSessionError) -> WorkoutLog {
        guard log.status == .inProgress else { throw .workoutNotActive }
        guard !log.sets.isEmpty else { throw .nothingLogged }

        var finished = log
        finished.status = .completed
        do { try sessions.save(finished) } catch { throw .couldNotFinishWorkout }
        return finished
    }

    func completedDays() throws(WorkoutSessionError) -> Set<Date> {
        do { return try sessions.completedDays() } catch { throw .couldNotLoadWorkouts }
    }

    /// Bodyweight exercises record 0 kg; every other exercise needs a weight above 0 and at most the maximum.
    private func isValidWeight(_ weight: Double, for exercise: Exercise) -> Bool {
        guard weight.isFinite else { return false }
        if exercise.loadType == "bodyweight" { return weight == 0 }
        return weight > 0 && weight <= Self.maximumWeightKg
    }
}
