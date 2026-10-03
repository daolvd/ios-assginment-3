//
//  HerLiftApp.swift
//  HerLift
//
//  Created by Van Dao Le on 1/10/2026.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct HerLiftApp: App {
    private let onboardingViewModel: OnboardingViewModel
    private let exerciseGuideViewModel: ExerciseGuideViewModel
    private let generatePlanViewModel: GeneratePlanViewModel
    private let myPlanViewModel: MyPlanViewModel
    private let reminderPresenter = ReminderPresenter()
    private let profileViewModel: ProfileViewModel
    @Environment(\.scenePhase) private var scenePhase

    init() {
        do {
            let goals = try JSONGoalRepository()
            let exercises = try JSONExerciseRepository()
            exerciseGuideViewModel = ExerciseGuideViewModel(
                browse: BrowseExerciseGuideUseCase(repository: exercises)
            )
            let profiles = try SwiftDataUserProfileRepository(modelContext: sharedModelContainer.mainContext)
            let plans = SwiftDataWorkoutPlanRepository(modelContext: sharedModelContainer.mainContext, exercises: exercises)
            let editPlan = EditWorkoutPlanUseCase(plans: plans, exercises: exercises)
            generatePlanViewModel = GeneratePlanViewModel(
                createPlan: CreateWorkoutPlanUseCase(
                    patterns: try JSONTrainingPatternRepository(), exercises: exercises, plans: plans,
                    startingWeights: try JSONStartingWeightRepository()),
                editPlan: editPlan,
                goals: goals.goals
            )
            let workoutSessions = WorkoutSessionUseCase(
                sessions: SwiftDataWorkoutSessionRepository(modelContext: sharedModelContainer.mainContext))
            UNUserNotificationCenter.current().delegate = reminderPresenter
            let reminders = WorkoutReminderUseCase(
                scheduler: UserNotificationsReminderScheduler(), time: UserDefaultsTrainingTime())
            myPlanViewModel = MyPlanViewModel(
                editPlan: editPlan, workoutSessions: workoutSessions, goals: goals.goals, reminders: reminders,
                widget: CoachWidgetUseCase(sync: AppGroupCoachWidgetSync()))
            generatePlanViewModel.restore()
            myPlanViewModel.load()
            onboardingViewModel = OnboardingViewModel(
                goals: goals.goals,
                saveProfile: SaveOnboardingProfileUseCase(repository: profiles)
            )
            let loadProfile = LoadOnboardingProfileUseCase(repository: profiles)
            onboardingViewModel.load(using: loadProfile)
            profileViewModel = ProfileViewModel(
                editor: onboardingViewModel, loadProfile: loadProfile, editPlan: editPlan, reminders: reminders)
            profileViewModel.refresh()
        } catch {
            fatalError("Could not prepare app repositories: \(error)")
        }
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            UserProfile.self,
            TrainingPlan.self,
            WorkoutDay.self,
            PlannedExercise.self,
            WorkoutSession.self,
            ExerciseSet.self
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
            ContentView(
                onboardingViewModel: onboardingViewModel, generatePlanViewModel: generatePlanViewModel,
                myPlanViewModel: myPlanViewModel, profileViewModel: profileViewModel)
                .environment(exerciseGuideViewModel)
                .tint(HerLiftTheme.primary)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { myPlanViewModel.ingestWidget() }
        }
        .modelContainer(sharedModelContainer)
    }
}
