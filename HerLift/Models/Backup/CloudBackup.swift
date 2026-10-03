import Foundation

/// Her answers and her plan as they are copied to her iCloud. The plan is nil while she has none.
nonisolated struct CloudBackup: Equatable, Sendable {
    let profile: OnboardingProfile
    let plan: WorkoutPlan?
    let savedAt: Date
}

/// A plan written down as plain data: exercises by catalogue id, so the copy does not depend on the catalogue
/// file's text.
nonisolated struct PlanBackupPayload: Codable, Equatable, Sendable {
    struct Workout: Codable, Equatable, Sendable {
        struct Exercise: Codable, Equatable, Sendable {
            let exerciseID: String
            let sets: Int
            let targetWeightKg: Double?
        }

        let weekday: Int
        let categoryIDs: [String]
        let exercises: [Exercise]
    }

    struct Forecast: Codable, Equatable, Sendable {
        let currentKg: Double
        let targetKg: Double
        let earliestWeek: Int
        let latestWeek: Int
    }

    let goalID: String
    /// "draft" or "active".
    let status: String
    let startedOn: Date?
    let forecast: Forecast?
    let workouts: [Workout]

    init(_ plan: WorkoutPlan) {
        goalID = plan.goalID
        status = plan.status.rawValue
        startedOn = plan.startedOn
        forecast = plan.weightForecast.map {
            Forecast(currentKg: $0.currentKg, targetKg: $0.targetKg, earliestWeek: $0.earliestWeek, latestWeek: $0.latestWeek)
        }
        workouts = plan.workouts.map { workout in
            Workout(
                weekday: workout.weekday, categoryIDs: workout.categoryIDs,
                exercises: workout.exercises.map {
                    Workout.Exercise(exerciseID: $0.exercise.id, sets: $0.sets, targetWeightKg: $0.targetWeightKg)
                })
        }
    }

    func json() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return String(decoding: try encoder.encode(self), as: UTF8.self)
    }
}
