import SwiftUI

/// The app's home: My Plan, the exercise Guide and her Profile as tabs, each with its own navigation stack.
struct MainTabView: View {
    let myPlanViewModel: MyPlanViewModel
    let profileViewModel: ProfileViewModel
    let generatePlanViewModel: GeneratePlanViewModel
    /// Runs after a rebuilt plan is waiting for her decision.
    let onRebuilt: () -> Void

    var body: some View {
        TabView {
            Tab("My Plan", systemImage: "calendar") {
                NavigationStack { MyPlanView(viewModel: myPlanViewModel) }
            }
            Tab("Guide", systemImage: "figure.strengthtraining.traditional") {
                NavigationStack { ExerciseGuideView() }
            }
            Tab("Profile", systemImage: "person.crop.circle") {
                NavigationStack {
                    ProfileView(viewModel: profileViewModel, generatePlan: generatePlanViewModel, onRebuilt: onRebuilt)
                }
            }
        }
        .tint(HerLiftTheme.primary)
    }
}
