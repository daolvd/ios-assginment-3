//
//  WorkoutSessionRepository.swift
//  HerLift
//
//  Created by Van Dao Le on 1/10/2026.
//

import Foundation
import SwiftData

@MainActor
protocol WorkoutSessionRepository {
    var sessions: [WorkoutSession] { get }
    func load() throws -> [WorkoutSession]
    func add(_ workoutSession: WorkoutSession) throws
    func update(_ workoutSession: WorkoutSession) throws
    func delete(_ workoutSession: WorkoutSession) throws
}

@MainActor
final class SwiftDataWorkoutSessionRepository: WorkoutSessionRepository {
    private(set) var sessions: [WorkoutSession] = []
    private let modelContext: ModelContext

    init(modelContext: ModelContext) throws {
        self.modelContext = modelContext
        sessions = try load()
    }

    @discardableResult
    func load() throws -> [WorkoutSession] {
        let descriptor = FetchDescriptor<WorkoutSession>(sortBy: [SortDescriptor(\.scheduledDate)])
        sessions = try modelContext.fetch(descriptor)
        return sessions
    }

    func add(_ workoutSession: WorkoutSession) throws {
        modelContext.insert(workoutSession)
        try save()
    }

    func update(_ workoutSession: WorkoutSession) throws {
        guard let stored = try load().first(where: { $0.id == workoutSession.id }) else { return }
        stored.scheduledDate = workoutSession.scheduledDate
        stored.statusRaw = workoutSession.statusRaw
        stored.startedAt = workoutSession.startedAt
        stored.completedAt = workoutSession.completedAt
        stored.workoutDay = workoutSession.workoutDay
        stored.sets = workoutSession.sets
        try save()
    }

    func delete(_ workoutSession: WorkoutSession) throws {
        guard let stored = try load().first(where: { $0.id == workoutSession.id }) else { return }
        modelContext.delete(stored)
        try save()
    }

    private func save() throws {
        try modelContext.save()
        try load()
    }
}
