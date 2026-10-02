import SwiftUI

struct ContentView: View {
    let onboardingViewModel: OnboardingViewModel

    @State private var hasFinishedOnboarding = false
    @State private var showsDebugGuide = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if hasFinishedOnboarding {
            NavigationStack {
                ExerciseGuideView()
            }
            .tint(HerLiftTheme.primary)
        } else {
            OnboardingView(viewModel: onboardingViewModel, onFinished: {
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
    ContentView(onboardingViewModel: OnboardingViewModel(goals: onboardingPreviewGoals))
        .environment(ExerciseGuideViewModel(
            browse: BrowseExerciseGuideUseCase(repository: (try? JSONExerciseRepository())!)))
}
