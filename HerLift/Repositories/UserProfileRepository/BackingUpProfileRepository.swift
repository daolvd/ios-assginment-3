import Foundation

/// A profile store that tells the backup after her answers are saved.
@MainActor
final class BackingUpProfileRepository: OnboardingProfileRepository {
    private let base: any OnboardingProfileRepository
    private let profileChanged: @MainActor () -> Void

    init(_ base: any OnboardingProfileRepository, profileChanged: @escaping @MainActor () -> Void) {
        self.base = base
        self.profileChanged = profileChanged
    }

    func loadOnboardingProfile() throws -> OnboardingProfile? { try base.loadOnboardingProfile() }

    func saveOnboardingProfile(_ profile: OnboardingProfile) throws {
        try base.saveOnboardingProfile(profile)
        profileChanged()
    }
}
