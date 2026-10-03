import SwiftUI

/// The app's home: My Plan, the exercise Guide and her Profile as tabs, each with its own navigation stack.
struct MainTabView: View {
    let myPlanViewModel: MyPlanViewModel
    let profileViewModel: ProfileViewModel
    let generatePlanViewModel: GeneratePlanViewModel
    /// Runs after a rebuilt plan is waiting for her decision.
    let onRebuilt: () -> Void

    private enum Page { case myPlan, guide, profile }

    @State private var page = Page.myPlan

    var body: some View {
        TabView(selection: $page) {
            Tab("My Plan", systemImage: "calendar", value: Page.myPlan) {
                NavigationStack { MyPlanView(viewModel: myPlanViewModel) }
            }
            Tab("Guide", systemImage: "figure.strengthtraining.traditional", value: Page.guide) {
                NavigationStack { ExerciseGuideView() }
            }
            Tab("Profile", systemImage: "person.crop.circle", value: Page.profile) {
                NavigationStack {
                    ProfileView(viewModel: profileViewModel, generatePlan: generatePlanViewModel, onRebuilt: onRebuilt)
                }
            }
        }
        .tint(HerLiftTheme.primary)
        .onOpenURL { url in
            if url == WorkoutLink.today { myPlanViewModel.openTodaysWorkout() }
        }
        .onChange(of: myPlanViewModel.openRequests) { page = .myPlan }
    }
}
