import Foundation

@MainActor
struct LoadOnboardingProfileUseCase {
    let repository: any OnboardingProfileRepository

    func execute() throws(OnboardingProfileError) -> OnboardingProfile? {
        do {
            return try repository.loadOnboardingProfile()
        } catch {
            throw .couldNotLoadProfile
        }
    }
}
