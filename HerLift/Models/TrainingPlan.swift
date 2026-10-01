//
//  TrainingPlan.swift
//  HerLift
//
//  Created by Van Dao Le on 1/10/2026.
//

import Foundation
import SwiftData

@Model
nonisolated final class TrainingPlan {
    @Attribute(.unique) var id: UUID
    var statusRaw: String
    var goalRaw: String
    var targetWeightKg: Double?
    var strategyRaw: String
    var generatorRaw: String
    var coachText: String
    var forecastMinWeeks: Int?
    var forecastMaxWeeks: Int?
    var targetWeeks: Int
    var createdAt: Date
    var startedOn: Date?
    var profile: UserProfile

    @Relationship(deleteRule: .cascade, inverse: \WorkoutDay.plan)
    var days: [WorkoutDay] = []

    init(
        id: UUID = UUID(), profile: UserProfile, statusRaw: String = "draft",
        goalRaw: String, targetWeightKg: Double? = nil,
        strategyRaw: String, generatorRaw: String, coachText: String,
        forecastMinWeeks: Int? = nil, forecastMaxWeeks: Int? = nil,
        targetWeeks: Int = 12, createdAt: Date = Date(), startedOn: Date? = nil
    ) {
        self.id = id
        self.profile = profile
        self.statusRaw = statusRaw
        self.goalRaw = goalRaw
        self.targetWeightKg = targetWeightKg
        self.strategyRaw = strategyRaw
        self.generatorRaw = generatorRaw
        self.coachText = coachText
        self.forecastMinWeeks = forecastMinWeeks
        self.forecastMaxWeeks = forecastMaxWeeks
        self.targetWeeks = targetWeeks
        self.createdAt = createdAt
        self.startedOn = startedOn
    }
}
