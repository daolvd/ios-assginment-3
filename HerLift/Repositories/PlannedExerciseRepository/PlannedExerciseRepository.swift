//
//  PlannedExerciseRepository.swift
//  HerLift
//
//  Created by Van Dao Le on 1/10/2026.
//

import Foundation
import SwiftData

@MainActor
protocol PlannedExerciseRepository {
    var exercises: [PlannedExercise] { get }
    func load() throws -> [PlannedExercise]
    func add(_ plannedExercise: PlannedExercise) throws
    func update(_ plannedExercise: PlannedExercise) throws
    func delete(_ plannedExercise: PlannedExercise) throws
}

@MainActor
final class SwiftDataPlannedExerciseRepository: PlannedExerciseRepository {
    private(set) var exercises: [PlannedExercise] = []
    private let modelContext: ModelContext

    init(modelContext: ModelContext) throws {
        self.modelContext = modelContext
        exercises = try load()
    }

    @discardableResult
    func load() throws -> [PlannedExercise] {
        let descriptor = FetchDescriptor<PlannedExercise>(sortBy: [SortDescriptor(\.sortIndex)])
        exercises = try modelContext.fetch(descriptor)
        return exercises
    }

    func add(_ plannedExercise: PlannedExercise) throws {
        modelContext.insert(plannedExercise)
        try save()
    }

    func update(_ plannedExercise: PlannedExercise) throws {
        guard let stored = try load().first(where: { $0.id == plannedExercise.id }) else { return }
        stored.sortIndex = plannedExercise.sortIndex
        stored.exerciseID = plannedExercise.exerciseID
        stored.targetSets = plannedExercise.targetSets
        stored.minimumReps = plannedExercise.minimumReps
        stored.maximumReps = plannedExercise.maximumReps
        stored.targetWeightKg = plannedExercise.targetWeightKg
        stored.restSeconds = plannedExercise.restSeconds
        stored.adjustmentDeclinedAt = plannedExercise.adjustmentDeclinedAt
        stored.workoutDay = plannedExercise.workoutDay
        try save()
    }

    func delete(_ plannedExercise: PlannedExercise) throws {
        guard let stored = try load().first(where: { $0.id == plannedExercise.id }) else { return }
        modelContext.delete(stored)
        try save()
    }

    private func save() throws {
        try modelContext.save()
        try load()
    }
}
