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

    init(goals: [Goal], input: OnboardingInput = OnboardingInput(),
         saveProfile: SaveOnboardingProfileUseCase? = nil) {
        self.goals = goals
        self.input = input
        self.saveProfile = saveProfile
    }

    var selectedGoal: Goal? { goals.first { $0.id == input.selectedGoalID } }

    var canFinish: Bool {
        guard selectedGoal != nil else { return false }
        guard selectedGoal?.requiresTargetWeight == true else { return true }
        return positiveNumber(input.targetWeight) != nil
    }

    var targetWeightMessage: String? {
        guard selectedGoal?.requiresTargetWeight == true, !input.targetWeight.isEmpty,
              positiveNumber(input.targetWeight) == nil else { return nil }
        return "Enter a valid target weight."
    }

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
        } catch {
            self.error = error
        }
    }

    @discardableResult
    func save() -> Bool {
        guard let saveProfile else { return false }
        do {
            savedProfile = try saveProfile.execute(input)
            error = nil
            return true
        } catch {
            self.error = error
            return false
        }
    }

    private func positiveNumber(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(trimmed.replacingOccurrences(of: ",", with: ".")), value.isFinite, value > 0 else {
            return nil
        }
        return value
    }
}
