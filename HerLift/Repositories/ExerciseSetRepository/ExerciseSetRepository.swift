//
//  ExerciseSetRepository.swift
//  HerLift
//
//  Created by Van Dao Le on 1/10/2026.
//

import Foundation
import SwiftData

@MainActor
protocol ExerciseSetRepository {
    var sets: [ExerciseSet] { get }
    func load() throws -> [ExerciseSet]
    func add(_ exerciseSet: ExerciseSet) throws
    func update(_ exerciseSet: ExerciseSet) throws
    func delete(_ exerciseSet: ExerciseSet) throws
}

@MainActor
final class SwiftDataExerciseSetRepository: ExerciseSetRepository {
    private(set) var sets: [ExerciseSet] = []
    private let modelContext: ModelContext

    init(modelContext: ModelContext) throws {
        self.modelContext = modelContext
        sets = try load()
    }

    @discardableResult
    func load() throws -> [ExerciseSet] {
        let descriptor = FetchDescriptor<ExerciseSet>(sortBy: [SortDescriptor(\.completedAt)])
        sets = try modelContext.fetch(descriptor)
        return sets
    }

    func add(_ exerciseSet: ExerciseSet) throws {
        modelContext.insert(exerciseSet)
        try save()
    }

    func update(_ exerciseSet: ExerciseSet) throws {
        guard let stored = try load().first(where: { $0.id == exerciseSet.id }) else { return }
        stored.plannedExerciseID = exerciseSet.plannedExerciseID
        stored.exerciseID = exerciseSet.exerciseID
        stored.setNumber = exerciseSet.setNumber
        stored.weightKg = exerciseSet.weightKg
        stored.repetitions = exerciseSet.repetitions
        stored.effortRaw = exerciseSet.effortRaw
        stored.completedAt = exerciseSet.completedAt
        stored.imageURL = exerciseSet.imageURL
        stored.videoURL = exerciseSet.videoURL
        stored.session = exerciseSet.session
        try save()
    }

    func delete(_ exerciseSet: ExerciseSet) throws {
        guard let stored = try load().first(where: { $0.id == exerciseSet.id }) else { return }
        modelContext.delete(stored)
        try save()
    }

    private func save() throws {
        try modelContext.save()
        try load()
    }
}
