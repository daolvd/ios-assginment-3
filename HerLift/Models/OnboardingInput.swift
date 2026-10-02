import Foundation

nonisolated enum ExperienceLevel: String, CaseIterable, Sendable {
    case beginner = "Beginner"
    case some = "Some"
}

/// Editable answers shared by the onboarding pages. Numeric text stays intact until saving.
nonisolated struct OnboardingInput: Equatable, Sendable {
    var age = ""
    var height = ""
    var weight = ""
    var experience = ExperienceLevel.beginner
    var trainingDays: Set<Int> = [1, 3, 6]
    var minutes = 45
    var healthNote = ""
    var clearedByDoctor = false
    var selectedGoalID: Goal.ID?
    var targetWeight = ""
}

/// A value snapshot; SwiftData objects remain inside the repository.
nonisolated struct OnboardingProfile: Equatable, Sendable {
    let age: Int
    let heightCm: Double
    let weightKg: Double
    let experience: ExperienceLevel
    let trainingWeekdays: [Int]
    let sessionMinutes: Int
    let healthNote: String?
    let clearedByDoctor: Bool
}
