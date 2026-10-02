import SwiftUI

struct ContentView: View {
    /// Where the app is: answering the onboarding questions, deciding about a new plan, or at home.
    private enum Route { case onboarding, review, myPlan }

    let onboardingViewModel: OnboardingViewModel
    let generatePlanViewModel: GeneratePlanViewModel
    let myPlanViewModel: MyPlanViewModel
    let profileViewModel: ProfileViewModel

    @State private var route: Route
    @State private var showsDebugGuide = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        onboardingViewModel: OnboardingViewModel, generatePlanViewModel: GeneratePlanViewModel,
        myPlanViewModel: MyPlanViewModel, profileViewModel: ProfileViewModel
    ) {
        self.onboardingViewModel = onboardingViewModel
        self.generatePlanViewModel = generatePlanViewModel
        self.myPlanViewModel = myPlanViewModel
        self.profileViewModel = profileViewModel

        // Reopening the app lands on the stored plan: home once it is accepted, the review before that.
        if myPlanViewModel.plan?.status == .active {
            _route = State(initialValue: .myPlan)
        } else if case .ready = generatePlanViewModel.state {
            _route = State(initialValue: .review)
        } else {
            _route = State(initialValue: .onboarding)
        }
    }

    var body: some View {
        switch route {
        case .myPlan:
            MainTabView(
                myPlanViewModel: myPlanViewModel, profileViewModel: profileViewModel,
                generatePlanViewModel: generatePlanViewModel, onRebuilt: { go(to: .review) })
        case .review:
            NavigationStack {
                GeneratePlanView(
                    viewModel: generatePlanViewModel,
                    onAccepted: {
                        myPlanViewModel.load()
                        go(to: .myPlan)
                    },
                    onChangeAnswers: { go(to: .onboarding) })
            }
            .tint(HerLiftTheme.primary)
        case .onboarding:
            OnboardingView(viewModel: onboardingViewModel, onFinished: {
                guard let profile = onboardingViewModel.savedProfile,
                      let goalID = onboardingViewModel.input.selectedGoalID else { return }
                generatePlanViewModel.generate(
                    profile: profile, goalID: goalID, targetWeightKg: onboardingViewModel.targetWeightKg)
                go(to: .review)
            }, onOpenGuide: { showsDebugGuide = true })
            .sheet(isPresented: $showsDebugGuide) {
                NavigationStack {
                    ExerciseGuideView()
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") { showsDebugGuide = false }
                            }
                        }
                }
                .tint(HerLiftTheme.primary)
            }
        }
    }

    private func go(to next: Route) {
        withAnimation(reduceMotion ? nil : .easeInOut) { route = next }
    }
}

#Preview {
    let exercises = try! JSONExerciseRepository()
    let plans = PreviewPlanStore()
    return ContentView(
        onboardingViewModel: OnboardingViewModel(goals: onboardingPreviewGoals),
        generatePlanViewModel: GeneratePlanViewModel(
            createPlan: CreateWorkoutPlanUseCase(
                patterns: try! JSONTrainingPatternRepository(), exercises: exercises, plans: plans),
            editPlan: EditWorkoutPlanUseCase(plans: plans, exercises: exercises),
            goals: onboardingPreviewGoals),
        myPlanViewModel: MyPlanViewModel(
            editPlan: EditWorkoutPlanUseCase(plans: plans, exercises: exercises), goals: onboardingPreviewGoals),
        profileViewModel: ProfileViewModel(
            editor: OnboardingViewModel(goals: onboardingPreviewGoals),
            loadProfile: LoadOnboardingProfileUseCase(repository: PreviewProfileStore()),
            editPlan: EditWorkoutPlanUseCase(plans: plans, exercises: exercises)))
        .environment(ExerciseGuideViewModel(browse: BrowseExerciseGuideUseCase(repository: exercises)))
}

/// Keeps the preview's plan in memory instead of the real store.
@MainActor
private final class PreviewPlanStore: WorkoutPlanRepository {
    private var plan: WorkoutPlan?
    func loadPlan() throws -> WorkoutPlan? { plan }
    func savePlan(_ plan: WorkoutPlan) throws { self.plan = plan }
    func deletePlan() throws { plan = nil }
}

@MainActor
private final class PreviewProfileStore: OnboardingProfileRepository {
    func loadOnboardingProfile() throws -> OnboardingProfile? { nil }
    func saveOnboardingProfile(_ profile: OnboardingProfile) throws {}
}
