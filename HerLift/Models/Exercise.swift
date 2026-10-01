//
//  Exercise.swift
//  HerLift
//
//  Created by Van Dao Le on 1/10/2026.
//

import Foundation

nonisolated struct Exercise: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let muscleGroup: String
    let primaryMuscle: String
    let secondaryMuscles: [String]
    let equipment: String
    let level: String
    let loadType: String
    let position: String
    let impact: String
    let minimumReps: Int
    let maximumReps: Int
    let defaultRestSeconds: Int
    let shortDescription: String
    let instructions: [String]
    let coachingCues: [String]
    let commonMistakes: [String]
    let breathing: String
    let alternativeExerciseIDs: [String]
    let videoFile: String?
    let imageURL: String?
    let videoURL: String?
}
