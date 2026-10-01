//
//  WorkoutDay.swift
//  HerLift
//
//  Created by Van Dao Le on 1/10/2026.
//

import Foundation
import SwiftData

@Model
nonisolated final class WorkoutDay {
    @Attribute(.unique) var id: UUID
    var sortIndex: Int
    var weekday: Int
    var title: String
    var estimatedMinutes: Int
    var plan: TrainingPlan

    @Relationship(deleteRule: .cascade, inverse: \PlannedExercise.workoutDay)
    var exercises: [PlannedExercise] = []

    // Removing a plan/day must not delete recorded workout history.
    @Relationship(deleteRule: .nullify, inverse: \WorkoutSession.workoutDay)
    var sessions: [WorkoutSession] = []

    init(
        id: UUID = UUID(), plan: TrainingPlan, sortIndex: Int,
        weekday: Int, title: String, estimatedMinutes: Int
    ) {
        self.id = id
        self.plan = plan
        self.sortIndex = sortIndex
        self.weekday = weekday
        self.title = title
        self.estimatedMinutes = estimatedMinutes
    }
}
