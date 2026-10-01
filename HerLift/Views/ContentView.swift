import SwiftUI

struct ContentView: View {
    let onboardingViewModel: OnboardingViewModel

    var body: some View {
        OnboardingView(viewModel: onboardingViewModel)
    }
}

#Preview {
    ContentView(onboardingViewModel: OnboardingViewModel(goals: onboardingPreviewGoals))
}
