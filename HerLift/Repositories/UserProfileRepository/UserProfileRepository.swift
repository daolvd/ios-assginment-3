//
//  UserProfileRepository.swift
//  HerLift
//
//  Created by Van Dao Le on 1/10/2026.
//

import Foundation
import SwiftData

@MainActor
protocol UserProfileRepository {
    var profiles: [UserProfile] { get }
    func load() throws -> [UserProfile]
    func add(_ userProfile: UserProfile) throws
    func update(_ userProfile: UserProfile) throws
    func delete(_ userProfile: UserProfile) throws
}

@MainActor
final class SwiftDataUserProfileRepository: UserProfileRepository {
    private(set) var profiles: [UserProfile] = []
    private let modelContext: ModelContext

    init(modelContext: ModelContext) throws {
        self.modelContext = modelContext
        profiles = try load()
    }

    @discardableResult
    func load() throws -> [UserProfile] {
        let descriptor = FetchDescriptor<UserProfile>(sortBy: [SortDescriptor(\.createdAt)])
        profiles = try modelContext.fetch(descriptor)
        return profiles
    }

    func add(_ userProfile: UserProfile) throws {
        modelContext.insert(userProfile)
        try save()
    }

    func update(_ userProfile: UserProfile) throws {
        guard let stored = try load().first(where: { $0.id == userProfile.id }) else { return }
        stored.age = userProfile.age
        stored.heightCm = userProfile.heightCm
        stored.weightKg = userProfile.weightKg
        stored.experienceRaw = userProfile.experienceRaw
        stored.trainingWeekdays = userProfile.trainingWeekdays
        stored.sessionMinutes = userProfile.sessionMinutes
        stored.healthNote = userProfile.healthNote
        stored.clearedByDoctor = userProfile.clearedByDoctor
        stored.createdAt = userProfile.createdAt
        stored.plans = userProfile.plans
        try save()
    }

    func delete(_ userProfile: UserProfile) throws {
        guard let stored = try load().first(where: { $0.id == userProfile.id }) else { return }
        modelContext.delete(stored)
        try save()
    }

    private func save() throws {
        try modelContext.save()
        try load()
    }
}
