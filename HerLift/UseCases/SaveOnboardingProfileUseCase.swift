import Foundation

@MainActor
struct SaveOnboardingProfileUseCase {
    let repository: any OnboardingProfileRepository

    func execute(_ input: OnboardingInput) throws(OnboardingProfileError) -> OnboardingProfile {
        guard let age = Int(input.age.trimmingCharacters(in: .whitespacesAndNewlines)), age > 0 else {
            throw .invalidAge
        }
        guard let height = positiveNumber(input.height) else { throw .invalidHeight }
        guard let weight = positiveNumber(input.weight) else { throw .invalidWeight }
        guard (2...7).contains(input.trainingDays.count), input.trainingDays.allSatisfy({ (1...7).contains($0) }) else {
            throw .unsupportedTrainingFrequency
        }
        guard (30...120).contains(input.minutes), input.minutes.isMultiple(of: 5) else {
            throw .invalidSessionDuration
        }
        let note = input.healthNote.trimmingCharacters(in: .whitespacesAndNewlines)
        let profile = OnboardingProfile(
            age: age, heightCm: height, weightKg: weight, experience: input.experience,
            trainingWeekdays: input.trainingDays.sorted(), sessionMinutes: input.minutes,
            healthNote: note.isEmpty ? nil : note,
            clearedByDoctor: !note.isEmpty && input.clearedByDoctor
        )
        do {
            try repository.saveOnboardingProfile(profile)
        } catch {
            throw .couldNotSaveProfile
        }
        return profile
    }

    private func positiveNumber(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(trimmed.replacingOccurrences(of: ",", with: ".")), value.isFinite, value > 0 else {
            return nil
        }
        return value
    }
}

nonisolated enum OnboardingProfileError: Error, LocalizedError, Equatable {
    case invalidAge, invalidHeight, invalidWeight
    case unsupportedTrainingFrequency, invalidSessionDuration, couldNotSaveProfile, couldNotLoadProfile

    var errorDescription: String? {
        switch self {
        case .invalidAge: "Enter a valid age."
        case .invalidHeight: "Enter a valid height in centimetres."
        case .invalidWeight: "Enter a valid weight in kilograms."
        case .unsupportedTrainingFrequency: "Choose between 2 and 7 training days."
        case .invalidSessionDuration: "Choose 30–120 minutes, in steps of 5."
        case .couldNotLoadProfile: "We couldn't load your saved profile."
        case .couldNotSaveProfile: "We couldn't save your profile."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .invalidAge, .invalidHeight, .invalidWeight: "Check your answers in About you and try again."
        case .unsupportedTrainingFrequency, .invalidSessionDuration: "Check your answers in Your training and try again."
        case .couldNotLoadProfile: "Try reopening the app to load your profile again."
        case .couldNotSaveProfile: "Your answers are still here — try again."
        }
    }
}
