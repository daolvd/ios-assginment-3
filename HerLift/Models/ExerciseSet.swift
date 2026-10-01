//
//  ExerciseSet.swift
//  HerLift
//
//  Created by Van Dao Le on 1/10/2026.
//

import Foundation
import SwiftData

@Model
nonisolated final class ExerciseSet {
    @Attribute(.unique) var id: UUID
    /// Historical identifier only: deleting the planned exercise never deletes a set.
    var plannedExerciseID: UUID
    var exerciseID: String
    var setNumber: Int
    var weightKg: Double
    var repetitions: Int
    var effortRaw: String
    var completedAt: Date
    var imageURL: String?
    var videoURL: String?
    var session: WorkoutSession

    init(
        id: UUID = UUID(), session: WorkoutSession, plannedExerciseID: UUID,
        exerciseID: String, setNumber: Int, weightKg: Double, repetitions: Int,
        effortRaw: String, completedAt: Date = Date(),
        imageURL: String? = nil, videoURL: String? = nil
    ) {
        self.id = id
        self.session = session
        self.plannedExerciseID = plannedExerciseID
        self.exerciseID = exerciseID
        self.setNumber = setNumber
        self.weightKg = weightKg
        self.repetitions = repetitions
        self.effortRaw = effortRaw
        self.completedAt = completedAt
        self.imageURL = imageURL
        self.videoURL = videoURL
    }
}
