//
//  PlannedExercise.swift
//  HerLift
//
//  Created by Van Dao Le on 1/10/2026.
//

import Foundation
import SwiftData

@Model
nonisolated final class PlannedExercise {
    @Attribute(.unique) var id: UUID
    var sortIndex: Int
    /// Logical reference to exercises.json, not a SwiftData relationship.
    var exerciseID: String
    var targetSets: Int
    var minimumReps: Int
    var maximumReps: Int
    /// Nil means starting weight must be calibrated in the first session.
    var targetWeightKg: Double?
    var restSeconds: Int
    var adjustmentDeclinedAt: Date?
    var workoutDay: WorkoutDay

    init(
        id: UUID = UUID(), workoutDay: WorkoutDay, sortIndex: Int,
        exerciseID: String, targetSets: Int, minimumReps: Int, maximumReps: Int,
        targetWeightKg: Double? = nil, restSeconds: Int,
        adjustmentDeclinedAt: Date? = nil
    ) {
        self.id = id
        self.workoutDay = workoutDay
        self.sortIndex = sortIndex
        self.exerciseID = exerciseID
        self.targetSets = targetSets
        self.minimumReps = minimumReps
        self.maximumReps = maximumReps
        self.targetWeightKg = targetWeightKg
        self.restSeconds = restSeconds
        self.adjustmentDeclinedAt = adjustmentDeclinedAt
    }
}
