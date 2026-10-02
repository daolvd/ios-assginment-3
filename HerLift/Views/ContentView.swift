import SwiftUI

struct ContentView: View {
    let onboardingViewModel: OnboardingViewModel
    let generatePlanViewModel: GeneratePlanViewModel

    @State private var hasFinishedOnboarding = false
    @State private var showsDebugGuide = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if hasFinishedOnboarding {
            NavigationStack {
                GeneratePlanView(viewModel: generatePlanViewModel, onChangeAnswers: {
                    withAnimation(reduceMotion ? nil : .easeInOut) { hasFinishedOnboarding = false }
                })
            }
            .tint(HerLiftTheme.primary)
        } else {
            OnboardingView(viewModel: onboardingViewModel, onFinished: {
                guard let profile = onboardingViewModel.savedProfile,
                      let goalID = onboardingViewModel.input.selectedGoalID else { return }
                generatePlanViewModel.generate(
                    profile: profile, goalID: goalID, targetWeightKg: onboardingViewModel.targetWeightKg)
                withAnimation(reduceMotion ? nil : .easeInOut) { hasFinishedOnboarding = true }
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
            goals: onboardingPreviewGoals))
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
