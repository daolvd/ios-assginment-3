//
//  HerLiftApp.swift
//  HerLift
//
//  Created by Van Dao Le on 1/10/2026.
//

import SwiftUI
import SwiftData

@main
struct HerLiftApp: App {
    private let onboardingViewModel: OnboardingViewModel
    private let exerciseGuideViewModel: ExerciseGuideViewModel

    init() {
        do {
            let goals = try JSONGoalRepository()
            let exercises = try JSONExerciseRepository()
            exerciseGuideViewModel = ExerciseGuideViewModel(
                browse: BrowseExerciseGuideUseCase(repository: exercises)
            )
            let profiles = try SwiftDataUserProfileRepository(modelContext: sharedModelContainer.mainContext)
            onboardingViewModel = OnboardingViewModel(
                goals: goals.goals,
                saveProfile: SaveOnboardingProfileUseCase(repository: profiles)
            )
            onboardingViewModel.load(using: LoadOnboardingProfileUseCase(repository: profiles))
        } catch {
            fatalError("Could not prepare app repositories: \(error)")
        }
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            UserProfile.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema, isStoredInMemoryOnly: false,
            groupContainer: .none, cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView(onboardingViewModel: onboardingViewModel)
                .environment(exerciseGuideViewModel)
                .tint(HerLiftTheme.primary)
        }
        .modelContainer(sharedModelContainer)
    }
}
