//
//  WorkoutDayRepository.swift
//  HerLift
//
//  Created by Van Dao Le on 1/10/2026.
//

import Foundation
import SwiftData

@MainActor
protocol WorkoutDayRepository {
    var days: [WorkoutDay] { get }
    func load() throws -> [WorkoutDay]
    func add(_ workoutDay: WorkoutDay) throws
    func update(_ workoutDay: WorkoutDay) throws
    func delete(_ workoutDay: WorkoutDay) throws
}

@MainActor
final class SwiftDataWorkoutDayRepository: WorkoutDayRepository {
    private(set) var days: [WorkoutDay] = []
    private let modelContext: ModelContext

    init(modelContext: ModelContext) throws {
        self.modelContext = modelContext
        days = try load()
    }

    @discardableResult
    func load() throws -> [WorkoutDay] {
        let descriptor = FetchDescriptor<WorkoutDay>(sortBy: [SortDescriptor(\.sortIndex)])
        days = try modelContext.fetch(descriptor)
        return days
    }

    func add(_ workoutDay: WorkoutDay) throws {
        modelContext.insert(workoutDay)
        try save()
    }

    func update(_ workoutDay: WorkoutDay) throws {
        guard let stored = try load().first(where: { $0.id == workoutDay.id }) else { return }
        stored.sortIndex = workoutDay.sortIndex
        stored.weekday = workoutDay.weekday
        stored.title = workoutDay.title
        stored.estimatedMinutes = workoutDay.estimatedMinutes
        stored.plan = workoutDay.plan
        stored.exercises = workoutDay.exercises
        stored.sessions = workoutDay.sessions
        try save()
    }

    func delete(_ workoutDay: WorkoutDay) throws {
        guard let stored = try load().first(where: { $0.id == workoutDay.id }) else { return }
        modelContext.delete(stored)
        try save()
    }

    private func save() throws {
        try modelContext.save()
        try load()
    }
}
