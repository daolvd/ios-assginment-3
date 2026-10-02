import Foundation
import SwiftData

@MainActor
final class SwiftDataWorkoutSessionRepository: WorkoutSessionRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func log(on day: Date) throws -> WorkoutLog? {
        guard let stored = try storedSession(on: day) else { return nil }
        let sets = try stored.sets.sorted { $0.sortIndex < $1.sortIndex }.map { item in
            guard let effort = PerceivedEffort(rawValue: item.effortRaw) else { throw CocoaError(.coderReadCorrupt) }
            return LoggedSet(
                exerciseID: item.exerciseID, setNumber: item.setNumber, weightKg: item.weightKg,
                repetitions: item.repetitions, effort: effort)
        }
        guard let status = WorkoutStatus(rawValue: stored.statusRaw) else { throw CocoaError(.coderReadCorrupt) }
        return WorkoutLog(
            date: stored.date, weekday: stored.weekday, status: status, sets: sets,
            startedAt: stored.startedAt, completedAt: stored.completedAt)
    }

    func save(_ log: WorkoutLog) throws {
        do {
            if let existing = try storedSession(on: log.date) { modelContext.delete(existing) }
            let session = WorkoutSession(
                date: log.date, weekday: log.weekday, statusRaw: log.status.rawValue,
                startedAt: log.startedAt, completedAt: log.completedAt)
            modelContext.insert(session)
            for (index, logged) in log.sets.enumerated() {
                let item = ExerciseSet(
                    sortIndex: index, exerciseID: logged.exerciseID, setNumber: logged.setNumber,
                    weightKg: logged.weightKg, repetitions: logged.repetitions, effortRaw: logged.effort.rawValue)
                item.session = session
            }
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    func completedDays() throws -> Set<Date> {
        let completed = WorkoutStatus.completed.rawValue
        let descriptor = FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.statusRaw == completed })
        return Set(try modelContext.fetch(descriptor).map(\.date))
    }

    private func storedSession(on day: Date) throws -> WorkoutSession? {
        let descriptor = FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.date == day })
        return try modelContext.fetch(descriptor).first
    }
}
