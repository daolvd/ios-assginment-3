import SwiftUI

/// Her answers, each opening the page where it can be changed, and Rebuild my plan.
/// The caller supplies the NavigationStack.
struct ProfileView: View {
    let viewModel: ProfileViewModel
    let generatePlan: GeneratePlanViewModel
    /// Runs after a new plan has been built and is waiting for her decision.
    let onRebuilt: () -> Void

    @State private var confirmsRebuild = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Stays on your phone.").font(.subheadline).foregroundStyle(HerLiftTheme.secondaryText)

                HLGroup {
                    row("About you", viewModel.aboutSummary) { ProfileAboutYouPage(editor: viewModel.editor) }
                    row("Your training", viewModel.trainingSummary) { ProfileTrainingPage(editor: viewModel.editor) }
                    row("Goal", viewModel.goalSummary) { ProfileGoalPage(editor: viewModel.editor) }
                }

                if viewModel.hasUnsavedChanges {
                    Text("Your plan only changes when you rebuild it.")
                        .font(.footnote).foregroundStyle(HerLiftTheme.secondaryText)
                }
                if let error = viewModel.planningError { HLInlineError(error) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 24)
        }
        .background(HerLiftTheme.background)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
        .onAppear { viewModel.refresh() }
        .safeAreaInset(edge: .bottom) {
            OnboardingStyle.primaryButton("Rebuild my plan") { confirmsRebuild = true }
                .disabled(!viewModel.canRebuild)
                .padding(.horizontal, 20).padding(.bottom, 12).padding(.top, 8)
                .background(HerLiftTheme.background)
        }
        .alert("Rebuild your plan?", isPresented: $confirmsRebuild) {
            Button("Rebuild", role: .destructive) {
                if viewModel.rebuild(using: generatePlan) { onRebuilt() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This replaces your current plan with a new one built from your changed answers.")
        }
        .alert("Check your answers", isPresented: Binding(
            get: { viewModel.editor.error != nil }, set: { if !$0 { viewModel.editor.error = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text([viewModel.editor.error?.errorDescription, viewModel.editor.error?.recoverySuggestion]
                .compactMap { $0 }.joined(separator: "\n"))
        }
    }

    private func row<Page: View>(_ title: String, _ subtitle: String, @ViewBuilder page: @escaping () -> Page)
        -> some View
    {
        NavigationLink(destination: page) {
            HLListRow(title: title, subtitle: subtitle, accessory: .chevron)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - The pages where answers are changed

/// The onboarding pages, reused as they are, with a keyboard Done button.
struct ProfileAboutYouPage: View {
    @Bindable var editor: OnboardingViewModel
    @FocusState private var focusedField: OnboardingField?

    var body: some View {
        AboutYouView(
            age: $editor.input.age, height: $editor.input.height, weight: $editor.input.weight,
            experience: $editor.input.experience, focusedField: $focusedField)
            .navigationTitle("About you")
            .navigationBarTitleDisplayMode(.large)
            .toolbar { keyboardDone($focusedField) }
    }
}

struct ProfileTrainingPage: View {
    @Bindable var editor: OnboardingViewModel
    @FocusState private var focusedField: OnboardingField?

    var body: some View {
        YourTrainingView(
            trainingDays: $editor.input.trainingDays, minutes: $editor.input.minutes,
            healthNote: $editor.input.healthNote, clearedByDoctor: $editor.input.clearedByDoctor,
            focusedField: $focusedField)
            .navigationTitle("Your training")
            .navigationBarTitleDisplayMode(.large)
            .toolbar { keyboardDone($focusedField) }
    }
}

struct ProfileGoalPage: View {
    @Bindable var editor: OnboardingViewModel
    @FocusState private var focusedField: OnboardingField?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        YourGoalView(
            goals: editor.goals, selectedGoalID: $editor.input.selectedGoalID,
            targetWeight: $editor.input.targetWeight, focusedField: $focusedField,
            actionTitle: "Done", canBuildPlan: editor.canFinish,
            targetWeightError: editor.targetWeightMessage, onBuildPlan: { dismiss() })
            .toolbar { keyboardDone($focusedField) }
    }
}

@ToolbarContentBuilder
private func keyboardDone(_ focusedField: FocusState<OnboardingField?>.Binding) -> some ToolbarContent {
    ToolbarItemGroup(placement: .keyboard) {
        Spacer()
        Button("Done") { focusedField.wrappedValue = nil }
    }
}
