import SwiftUI

/// Her answers, each opening the page where it can be changed, and Rebuild my plan.
/// The caller supplies the NavigationStack.
struct ProfileView: View {
    @Bindable var viewModel: ProfileViewModel
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
                    row("Training time", viewModel.reminderSummary) { ProfileTrainingTimePage(viewModel: viewModel) }
                }

                Button("Send test reminder", action: viewModel.sendTestReminder)
                    .font(.subheadline).frame(minHeight: 44)

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

#Preview("Profile") {
    NavigationStack {
        ProfileView(
            viewModel: previewProfileViewModel(plan: previewPlan()), generatePlan: previewGeneratePlan(ready: false),
            onRebuilt: {})
    }
    .tint(HerLiftTheme.primary)
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

#Preview("Profile · About you") {
    NavigationStack { ProfileAboutYouPage(editor: previewEditor()) }
        .tint(HerLiftTheme.primary)
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

#Preview("Profile · Your training") {
    NavigationStack { ProfileTrainingPage(editor: previewEditor()) }
        .tint(HerLiftTheme.primary)
}

/// The time of day she trains; the reminder comes 30 minutes before.
struct ProfileTrainingTimePage: View {
    @Bindable var viewModel: ProfileViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            DatePicker("Training time", selection: $viewModel.trainingTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
            Text("We remind you 30 minutes before, on the days you train.")
                .font(.footnote).foregroundStyle(HerLiftTheme.secondaryText)
            Spacer()
        }
        .padding(.horizontal, 20)
        .background(HerLiftTheme.background)
        .navigationTitle("Training time")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview("Profile · Training time") {
    NavigationStack { ProfileTrainingTimePage(viewModel: previewProfileViewModel(plan: previewPlan())) }
        .tint(HerLiftTheme.primary)
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

#Preview("Profile · Goal") {
    NavigationStack { ProfileGoalPage(editor: previewEditor()) }
        .tint(HerLiftTheme.primary)
}

@ToolbarContentBuilder
private func keyboardDone(_ focusedField: FocusState<OnboardingField?>.Binding) -> some ToolbarContent {
    ToolbarItemGroup(placement: .keyboard) {
        Spacer()
        Button("Done") { focusedField.wrappedValue = nil }
    }
}

// MARK: - Preview data

/// The goals from the bundled catalogue.
@MainActor
private func previewGoals() -> [Goal] { (try? JSONGoalRepository().goals) ?? [] }

/// Today's workout: machine chest press with a target weight, then a bodyweight core exercise.
@MainActor
private func previewWorkout() -> PlannedWorkout {
    let catalogue = try! JSONExerciseRepository().exercises
    func planned(_ id: String, sets: Int, kg: Double? = nil) -> WorkoutExercise {
        WorkoutExercise(exercise: catalogue.first { $0.id == id }!, sets: sets, targetWeightKg: kg)
    }
    return PlannedWorkout(
        weekday: PlanWeek.mondayBasedWeekday(of: Date(), calendar: .current), categoryIDs: ["chest", "core"],
        exercises: [planned("machine-chest-press", sets: 3, kg: 20), planned("reverse-crunch", sets: 2)])
}

/// An accepted fat-loss plan started a week ago: today's workout and legs on two other days.
@MainActor
private func previewPlan() -> WorkoutPlan {
    let today = previewWorkout()
    let legs = [(today.weekday + 1) % 7 + 1, (today.weekday + 3) % 7 + 1].map {
        PlannedWorkout(weekday: $0, categoryIDs: ["legs"], exercises: today.exercises)
    }
    return WorkoutPlan(
        goalID: "loseFat", workouts: (legs + [today]).sorted { $0.weekday < $1.weekday }, status: .active,
        weightForecast: WeightLossForecast(currentKg: 68, targetKg: 62, earliestWeek: 12, latestWeek: 24),
        startedOn: Calendar.current.date(byAdding: .day, value: -7, to: Date()))
}

private let previewProfile = OnboardingProfile(
    age: 29, heightCm: 165, weightKg: 68, experience: .beginner, trainingWeekdays: [1, 3, 6],
    sessionMinutes: 45, healthNote: nil, clearedByDoctor: false)

/// The plan kept in memory.
@MainActor
private final class PreviewPlanStore: WorkoutPlanRepository {
    private var plan: WorkoutPlan?
    init(_ plan: WorkoutPlan? = nil) { self.plan = plan }
    func loadPlan() throws -> WorkoutPlan? { plan }
    func savePlan(_ plan: WorkoutPlan) throws { self.plan = plan }
    func deletePlan() throws { plan = nil }
}

/// Her answers kept in memory.
@MainActor
private final class PreviewProfileStore: OnboardingProfileRepository {
    private var profile: OnboardingProfile?
    init(_ profile: OnboardingProfile? = nil) { self.profile = profile }
    func loadOnboardingProfile() throws -> OnboardingProfile? { profile }
    func saveOnboardingProfile(_ profile: OnboardingProfile) throws { self.profile = profile }
}

@MainActor
private func previewGeneratePlan(ready: Bool) -> GeneratePlanViewModel {
    let exercises = try! JSONExerciseRepository()
    let store = PreviewPlanStore()
    let viewModel = GeneratePlanViewModel(
        createPlan: CreateWorkoutPlanUseCase(patterns: try! JSONTrainingPatternRepository(), exercises: exercises, plans: store),
        editPlan: EditWorkoutPlanUseCase(plans: store, exercises: exercises), goals: previewGoals())
    if ready { viewModel.generate(profile: previewProfile, goalID: "loseFat", targetWeightKg: 62) }
    return viewModel
}

@MainActor
private func previewProfileViewModel(plan: WorkoutPlan?) -> ProfileViewModel {
    let profiles = PreviewProfileStore(previewProfile)
    let viewModel = ProfileViewModel(
        editor: OnboardingViewModel(goals: previewGoals()), loadProfile: LoadOnboardingProfileUseCase(repository: profiles),
        editPlan: EditWorkoutPlanUseCase(plans: PreviewPlanStore(plan), exercises: try! JSONExerciseRepository()))
    viewModel.refresh()
    return viewModel
}

/// Her saved answers, ready to edit.
@MainActor
private func previewEditor() -> OnboardingViewModel {
    let viewModel = OnboardingViewModel(goals: previewGoals())
    viewModel.load(using: LoadOnboardingProfileUseCase(repository: PreviewProfileStore(previewProfile)))
    return viewModel
}
