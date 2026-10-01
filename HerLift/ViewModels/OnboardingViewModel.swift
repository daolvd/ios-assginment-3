import Foundation
import Observation

@MainActor
@Observable
final class OnboardingViewModel {
    let goals: [Goal]
    var input: OnboardingInput
    private(set) var savedProfile: OnboardingProfile?
    var error: OnboardingProfileError?
    @ObservationIgnored private let saveProfile: SaveOnboardingProfileUseCase?

    /// Omit the use case only for view previews; saving requires a repository supplied by the app.
    init(goals: [Goal], input: OnboardingInput = OnboardingInput(),
         saveProfile: SaveOnboardingProfileUseCase? = nil) {
        self.goals = goals
        self.input = input
        self.saveProfile = saveProfile
    }

    var canSave: Bool { saveProfile != nil }

    func load(using useCase: LoadOnboardingProfileUseCase) {
        do {
            guard let profile = try useCase.execute() else { return }
            input.age = String(profile.age)
            input.height = String(profile.heightCm)
            input.weight = String(profile.weightKg)
            input.experience = profile.experience
            input.trainingDays = Set(profile.trainingWeekdays)
            input.minutes = profile.sessionMinutes
            input.healthNote = profile.healthNote ?? ""
            input.clearedByDoctor = profile.clearedByDoctor
            savedProfile = profile
            error = nil
        } catch {
            self.error = error
        }
    }

    @discardableResult
    func save() -> Bool {
        guard let saveProfile else {
            error = .couldNotSaveProfile
            return false
        }
        do {
            savedProfile = try saveProfile.execute(input)
            error = nil
            return true
        } catch {
            self.error = error
            return false
        }
    }
}
