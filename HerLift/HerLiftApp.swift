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
    private let exerciseRepository: JSONExerciseRepository

    init() {
        do {
            exerciseRepository = try JSONExerciseRepository()
            let goals = try JSONGoalRepository()
            let profiles = try SwiftDataUserProfileRepository(modelContext: sharedModelContainer.mainContext)
            let plans = try SwiftDataTrainingPlanRepository(modelContext: sharedModelContainer.mainContext)
            let planner = FoundationModelPlanGenerator(catalogue: exerciseRepository.exercises)
            onboardingViewModel = OnboardingViewModel(
                goals: goals.goals,
                exercises: exerciseRepository.exercises,
                saveProfile: SaveOnboardingProfileUseCase(repository: profiles),
                createPlan: CreatePersonalisedPlanUseCase(generator: planner, catalogue: exerciseRepository.exercises,
                                                         repository: plans)
            )
            onboardingViewModel.load(using: LoadOnboardingProfileUseCase(repository: profiles))
            onboardingViewModel.loadSavedPlan()
        } catch {
            fatalError("Could not prepare app repositories: \(error)")
        }
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            UserProfile.self,
            TrainingPlan.self,
            WorkoutDay.self,
            PlannedExercise.self,
            WorkoutSession.self,
            ExerciseSet.self,
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
                .tint(HerLiftTheme.primary)
        }
        .modelContainer(sharedModelContainer)
    }
}
