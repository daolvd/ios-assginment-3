//
//  UserProfile.swift
//  HerLift
//
//  Created by Van Dao Le on 1/10/2026.
//

import Foundation
import SwiftData

@Model
nonisolated final class UserProfile {
    @Attribute(.unique) var id: UUID
    var age: Int
    var heightCm: Double
    var weightKg: Double
    var experienceRaw: String
    /// Monday = 1, Sunday = 7. The use case validates 2–4 distinct days.
    var trainingWeekdays: [Int]
    var sessionMinutes: Int
    var healthNote: String?
    var clearedByDoctor: Bool
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \TrainingPlan.profile)
    var plans: [TrainingPlan] = []

    init(
        id: UUID = UUID(), age: Int, heightCm: Double, weightKg: Double,
        experienceRaw: String, trainingWeekdays: [Int], sessionMinutes: Int,
        healthNote: String? = nil, clearedByDoctor: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.age = age
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.experienceRaw = experienceRaw
        self.trainingWeekdays = trainingWeekdays
        self.sessionMinutes = sessionMinutes
        self.healthNote = healthNote
        self.clearedByDoctor = clearedByDoctor
        self.createdAt = createdAt
    }
}
