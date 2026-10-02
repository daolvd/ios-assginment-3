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
        return positiveNumber(input.targetWeight) != nil && targetWeightMessage == nil
    }

    /// The fat-loss target, or nil for goals without one or when nothing valid is typed yet.
    var targetWeightKg: Double? {
        selectedGoal?.requiresTargetWeight == true ? positiveNumber(input.targetWeight) : nil
    }

    var targetWeightMessage: String? {
        guard selectedGoal?.requiresTargetWeight == true, !input.targetWeight.isEmpty else { return nil }
        guard let target = positiveNumber(input.targetWeight) else { return "Enter a valid target weight." }
        if let height = positiveNumber(input.height), !ForecastCalculator.isHealthyTarget(target, heightCm: height) {
            return "This target is below a healthy weight for your height. "
                + "Choose \(ForecastCalculator.minimumHealthyWeightKg(heightCm: height)) kg or more."
        }
        if let weight = positiveNumber(input.weight), target >= weight {
            return "Choose a target below your current weight."
        }
        return nil
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
