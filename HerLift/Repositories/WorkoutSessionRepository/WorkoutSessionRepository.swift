import Foundation

/// Stores each day's workout log. Days are the start of the day.
@MainActor
protocol WorkoutSessionRepository {
    func log(on day: Date) throws -> WorkoutLog?
    /// Creates the log for `log.date` or replaces the one already stored for that day.
    func save(_ log: WorkoutLog) throws
    /// The days on which a workout was finished.
    func completedDays() throws -> Set<Date>
}
