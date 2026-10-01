//
//  TrainingPlanRepository.swift
//  HerLift
//
//  Created by Van Dao Le on 1/10/2026.
//

import Foundation
import SwiftData

@MainActor
protocol TrainingPlanRepository {
    var plans: [TrainingPlan] { get }
    func load() throws -> [TrainingPlan]
    func add(_ trainingPlan: TrainingPlan) throws
    func update(_ trainingPlan: TrainingPlan) throws
    func delete(_ trainingPlan: TrainingPlan) throws
}

@MainActor
final class SwiftDataTrainingPlanRepository: TrainingPlanRepository {
    private(set) var plans: [TrainingPlan] = []
    private let modelContext: ModelContext

    init(modelContext: ModelContext) throws {
        self.modelContext = modelContext
        plans = try load()
    }

    @discardableResult
    func load() throws -> [TrainingPlan] {
        let descriptor = FetchDescriptor<TrainingPlan>(sortBy: [SortDescriptor(\.createdAt)])
        plans = try modelContext.fetch(descriptor)
        return plans
    }

    func add(_ trainingPlan: TrainingPlan) throws {
        modelContext.insert(trainingPlan)
        try save()
    }

    func update(_ trainingPlan: TrainingPlan) throws {
        guard let stored = try load().first(where: { $0.id == trainingPlan.id }) else { return }
        stored.statusRaw = trainingPlan.statusRaw
        stored.goalRaw = trainingPlan.goalRaw
        stored.targetWeightKg = trainingPlan.targetWeightKg
        stored.strategyRaw = trainingPlan.strategyRaw
        stored.generatorRaw = trainingPlan.generatorRaw
        stored.coachText = trainingPlan.coachText
        stored.forecastMinWeeks = trainingPlan.forecastMinWeeks
        stored.forecastMaxWeeks = trainingPlan.forecastMaxWeeks
        stored.targetWeeks = trainingPlan.targetWeeks
        stored.createdAt = trainingPlan.createdAt
        stored.startedOn = trainingPlan.startedOn
        stored.profile = trainingPlan.profile
        stored.days = trainingPlan.days
        try save()
    }

    func delete(_ trainingPlan: TrainingPlan) throws {
        guard let stored = try load().first(where: { $0.id == trainingPlan.id }) else { return }
        modelContext.delete(stored)
        try save()
    }

    private func save() throws {
        try modelContext.save()
        try load()
    }
}
