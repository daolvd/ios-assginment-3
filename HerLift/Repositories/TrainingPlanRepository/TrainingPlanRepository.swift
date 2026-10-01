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
        do {
            let profiles = try modelContext.fetch(FetchDescriptor<UserProfile>(sortBy: [SortDescriptor(\.createdAt)]))
            if let savedProfile = profiles.last {
                let snapshot = trainingPlan.profile
                guard savedProfile.age == snapshot.age, savedProfile.heightCm == snapshot.heightCm,
                      savedProfile.weightKg == snapshot.weightKg, savedProfile.experienceRaw == snapshot.experienceRaw,
                      savedProfile.trainingWeekdays == snapshot.trainingWeekdays, savedProfile.sessionMinutes == snapshot.sessionMinutes,
                      savedProfile.healthNote == snapshot.healthNote, savedProfile.clearedByDoctor == snapshot.clearedByDoctor
                else { throw CocoaError(.coderReadCorrupt) }
                // EN: Reuse the saved onboarding profile rather than inserting a duplicate.
                // VI: Dùng profile onboarding đã lưu, không tạo profile trùng.
                trainingPlan.profile = savedProfile
            }
            let previous = try load().filter {
                $0.statusRaw == "draft" && $0.profile.id == trainingPlan.profile.id && $0.id != trainingPlan.id
            }
            modelContext.insert(trainingPlan)
            // EN: Replace only previous unaccepted plans; keep active plans until Accept is implemented.
            // VI: Chỉ thay plan chưa chấp nhận; giữ plan active cho đến luồng Accept.
            previous.forEach { modelContext.delete($0) }
            try save()
        } catch {
            modelContext.rollback()
            throw error
        }
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
        do {
            modelContext.delete(stored)
            try save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    private func save() throws {
        try modelContext.save()
        try load()
    }
}
