import Foundation

@MainActor
protocol OnboardingProfileRepository {
    func loadOnboardingProfile() throws -> OnboardingProfile?
    func saveOnboardingProfile(_ profile: OnboardingProfile) throws
}
