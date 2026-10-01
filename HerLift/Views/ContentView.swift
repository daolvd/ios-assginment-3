import SwiftUI

struct ContentView: View {
    let onboardingViewModel: OnboardingViewModel
    @State private var generationTask: Task<Void, Never>?

    var body: some View {
        Group {
            switch onboardingViewModel.generationPhase {
            case .editing:
                OnboardingView(viewModel: onboardingViewModel, onBuildPlan: buildPlan)
            case .building, .failed:
                PlanGenerationView(phase: onboardingViewModel.generationPhase == .building ? .building : .failed,
                                   plannerLabel: onboardingViewModel.plannerLabel,
                                   error: onboardingViewModel.generationError,
                                   onRetry: buildPlan, onChangeAnswers: changeAnswers)
            case .ready:
                if let plan = onboardingViewModel.plan {
                    PlanReviewView(plan: plan, goalTitle: onboardingViewModel.selectedGoal?.title,
                                   exercises: onboardingViewModel.exercises,
                                   milestones: onboardingViewModel.planMilestones,
                                   onStartOver: changeAnswers)
                }
            }
        }
        .onDisappear { generationTask?.cancel() }
    }

    private func buildPlan() {
        generationTask?.cancel()
        generationTask = Task { await onboardingViewModel.buildPlan() }
    }

    private func changeAnswers() {
        generationTask?.cancel()
        generationTask = nil
        onboardingViewModel.changeAnswers()
    }
}

#Preview {
    ContentView(onboardingViewModel: OnboardingViewModel(goals: onboardingPreviewGoals))
}
