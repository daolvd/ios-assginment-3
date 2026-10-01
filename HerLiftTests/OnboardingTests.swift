import Foundation
import Testing
import SwiftData
@testable import HerLift

@MainActor
struct OnboardingTests {
    @Test func saveProfilePreservesAnswersAndNormalisesHealthNote() throws {
        let repository = ProfileRepositoryStub()
        let useCase = SaveOnboardingProfileUseCase(repository: repository)
        var input = OnboardingInput()
        input.age = "29"
        input.height = "165"
        input.weight = "62"
        input.experience = .some
        input.trainingDays = [7, 1]
        input.minutes = 120
        input.healthNote = "  Mild asthma.  "
        input.clearedByDoctor = true

        let saved = try useCase.execute(input)

        #expect(saved.age == 29)
        #expect(saved.heightCm == 165)
        #expect(saved.weightKg == 62)
        #expect(saved.experience == .some)
        #expect(saved.trainingWeekdays == [1, 7])
        #expect(saved.sessionMinutes == 120)
        #expect(saved.healthNote == "Mild asthma.")
        #expect(saved.clearedByDoctor)
        #expect(repository.saved == saved)
    }

    @Test func invalidAnswersNeverReachRepository() {
        let repository = ProfileRepositoryStub()
        let useCase = SaveOnboardingProfileUseCase(repository: repository)
        var input = validInput()
        input.trainingDays = [1]
        #expect(throws: OnboardingProfileError.unsupportedTrainingFrequency) {
            try useCase.execute(input)
        }
        input = validInput()
        input.weight = "nan"
        #expect(throws: OnboardingProfileError.invalidWeight) { try useCase.execute(input) }
        input = validInput()
        input.minutes = 33
        #expect(throws: OnboardingProfileError.invalidSessionDuration) { try useCase.execute(input) }
        #expect(repository.saved == nil)
    }

    @Test func saveFailureKeepsViewModelAnswersAndDoesNotReportSuccess() {
        let repository = ProfileRepositoryStub()
        repository.fails = true
        let viewModel = OnboardingViewModel(
            goals: [], input: validInput(),
            saveProfile: SaveOnboardingProfileUseCase(repository: repository)
        )
        #expect(!viewModel.save())
        #expect(viewModel.input.weight == "62")
        #expect(viewModel.savedProfile == nil)
        #expect(viewModel.error == .couldNotSaveProfile)
    }

    @Test func savingTwiceUpdatesOneProfileAndCanReadItBack() throws {
        let schema = Schema([UserProfile.self, TrainingPlan.self, WorkoutDay.self,
                             PlannedExercise.self, WorkoutSession.self, ExerciseSet.self])
        let container = try ModelContainer(
            for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
        let repository = try SwiftDataUserProfileRepository(modelContext: ModelContext(container))
        let save = SaveOnboardingProfileUseCase(repository: repository)
        _ = try save.execute(validInput())
        let originalID = try #require(repository.profiles.first?.id)
        var updated = validInput()
        updated.weight = "63,5"
        _ = try save.execute(updated)

        let reopened = try SwiftDataUserProfileRepository(modelContext: ModelContext(container))
        let loaded = try LoadOnboardingProfileUseCase(repository: reopened).execute()
        #expect(reopened.profiles.count == 1)
        #expect(reopened.profiles.first?.id == originalID)
        #expect(loaded?.weightKg == 63.5)
    }

    @Test func loadingSavedProfilePrefillsAnswersWithoutChangingGoal() {
        let repository = ProfileRepositoryStub()
        repository.saved = OnboardingProfile(
            age: 29, heightCm: 165, weightKg: 62, experience: .some,
            trainingWeekdays: [1, 7], sessionMinutes: 120,
            healthNote: "Mild asthma.", clearedByDoctor: true
        )
        var input = OnboardingInput()
        input.selectedGoalID = "buildStrength"
        let viewModel = OnboardingViewModel(goals: [], input: input)
        viewModel.load(using: LoadOnboardingProfileUseCase(repository: repository))
        #expect(viewModel.input.age == "29")
        #expect(viewModel.input.experience == .some)
        #expect(viewModel.input.trainingDays == [1, 7])
        #expect(viewModel.input.minutes == 120)
        #expect(viewModel.input.healthNote == "Mild asthma.")
        #expect(viewModel.input.clearedByDoctor)
        #expect(viewModel.input.selectedGoalID == "buildStrength")
    }

    private func validInput() -> OnboardingInput {
        var input = OnboardingInput()
        input.age = "29"
        input.height = "165"
        input.weight = "62"
        return input
    }
}

@MainActor
private final class ProfileRepositoryStub: OnboardingProfileRepository {
    var saved: OnboardingProfile?
    var fails = false

    func loadOnboardingProfile() throws -> OnboardingProfile? { saved }

    func saveOnboardingProfile(_ profile: OnboardingProfile) throws {
        if fails { throw CocoaError(.fileWriteUnknown) }
        saved = profile
    }
}
