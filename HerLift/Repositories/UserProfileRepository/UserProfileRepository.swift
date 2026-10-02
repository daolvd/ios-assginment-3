//
//  UserProfileRepository.swift
//  HerLift
//
//  Created by Van Dao Le on 1/10/2026.
//

import Foundation
import SwiftData

@MainActor
final class SwiftDataUserProfileRepository {
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

    private func save() throws {
        try modelContext.save()
        try load()
    }
}

extension SwiftDataUserProfileRepository: OnboardingProfileRepository {
    func loadOnboardingProfile() throws -> OnboardingProfile? {
        guard let stored = try load().last else { return nil }
        guard let experience = ExperienceLevel(rawValue: stored.experienceRaw) else {
            throw CocoaError(.coderReadCorrupt)
        }
        return OnboardingProfile(
            age: stored.age, heightCm: stored.heightCm, weightKg: stored.weightKg,
            experience: experience, trainingWeekdays: stored.trainingWeekdays,
            sessionMinutes: stored.sessionMinutes, healthNote: stored.healthNote,
            clearedByDoctor: stored.clearedByDoctor
        )
    }

    func saveOnboardingProfile(_ profile: OnboardingProfile) throws {
        do {
            // Reuse the current profile without replacing its identity or linked plans.
            let stored = try load().last ?? UserProfile(
                age: profile.age, heightCm: profile.heightCm, weightKg: profile.weightKg,
                experienceRaw: profile.experience.rawValue,
                trainingWeekdays: profile.trainingWeekdays, sessionMinutes: profile.sessionMinutes
            )
            if stored.modelContext == nil { modelContext.insert(stored) }
            stored.age = profile.age
            stored.heightCm = profile.heightCm
            stored.weightKg = profile.weightKg
            stored.experienceRaw = profile.experience.rawValue
            stored.trainingWeekdays = profile.trainingWeekdays
            stored.sessionMinutes = profile.sessionMinutes
            stored.healthNote = profile.healthNote
            stored.clearedByDoctor = profile.clearedByDoctor
            try save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }
}
