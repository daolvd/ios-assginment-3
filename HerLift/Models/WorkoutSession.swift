//
//  WorkoutSession.swift
//  HerLift
//
//  Created by Van Dao Le on 1/10/2026.
//

import Foundation
import SwiftData

@Model
nonisolated final class WorkoutSession {
    @Attribute(.unique) var id: UUID
    var scheduledDate: Date
    var statusRaw: String
    var startedAt: Date?
    var completedAt: Date?
    /// Nil after the associated day/plan is deleted; recorded sets remain.
    var workoutDay: WorkoutDay?

    @Relationship(deleteRule: .cascade, inverse: \ExerciseSet.session)
    var sets: [ExerciseSet] = []

    init(
        id: UUID = UUID(), workoutDay: WorkoutDay?, scheduledDate: Date,
        statusRaw: String = "scheduled", startedAt: Date? = nil, completedAt: Date? = nil
    ) {
        self.id = id
        self.workoutDay = workoutDay
        self.scheduledDate = scheduledDate
        self.statusRaw = statusRaw
        self.startedAt = startedAt
        self.completedAt = completedAt
    }
}
