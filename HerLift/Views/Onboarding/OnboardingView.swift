import SwiftUI

struct OnboardingView: View {
    @State private var viewModel: OnboardingViewModel
    @State private var page = 0
    @State private var showsGoal = false
    @FocusState private var focusedField: OnboardingField?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let onFinished: () -> Void
    private let onOpenGuide: (() -> Void)?

    /// `onFinished` runs after the answers have been saved successfully.
    /// `onOpenGuide` adds a temporary Guide button on the first page for debugging.
    init(viewModel: OnboardingViewModel, onFinished: @escaping () -> Void = {},
         onOpenGuide: (() -> Void)? = nil) {
        _viewModel = State(initialValue: viewModel)
        self.onFinished = onFinished
        self.onOpenGuide = onOpenGuide
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            TabView(selection: $page) {
                AboutYouView(age: $viewModel.input.age, height: $viewModel.input.height,
                             weight: $viewModel.input.weight, experience: $viewModel.input.experience,
                             focusedField: $focusedField)
                    .tag(0)
                YourTrainingView(trainingDays: $viewModel.input.trainingDays, minutes: $viewModel.input.minutes,
                                 healthNote: $viewModel.input.healthNote,
                                 clearedByDoctor: $viewModel.input.clearedByDoctor,
                                 focusedField: $focusedField)
                    .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .background(HerLiftTheme.background)
            .navigationTitle(page == 0 ? "About you" : "Your training")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Text("\(page + 1) of 2").font(.footnote).foregroundStyle(HerLiftTheme.secondaryText)
                }
                if page == 1 {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Back", systemImage: "chevron.left") { changePage(to: 0) }
                    }
                } else if let onOpenGuide {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Guide", action: onOpenGuide)
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
            .safeAreaInset(edge: .bottom) {
                OnboardingStyle.primaryButton(page == 0 ? "Next" : "Continue") {
                    focusedField = nil
                    if page == 0 { changePage(to: 1) }
                    else { showsGoal = true }
                }
                .padding(.horizontal, 20).padding(.bottom, 12)
                .background(HerLiftTheme.background)
            }
            .navigationDestination(isPresented: $showsGoal) {
                YourGoalView(goals: viewModel.goals, selectedGoalID: $viewModel.input.selectedGoalID,
                             targetWeight: $viewModel.input.targetWeight, focusedField: $focusedField,
                             actionTitle: "Finish onboarding", canBuildPlan: viewModel.canFinish,
                             targetWeightError: viewModel.targetWeightMessage, onBuildPlan: finish)
            }
        }
        .tint(HerLiftTheme.primary)
        .alert("Check your answers", isPresented: Binding(
            get: { viewModel.error != nil }, set: { if !$0 { viewModel.error = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text([viewModel.error?.errorDescription, viewModel.error?.recoverySuggestion]
                .compactMap { $0 }.joined(separator: "\n"))
        }
    }

    private func finish() {
        guard viewModel.save() else { return }
        onFinished()
    }

    private func changePage(to nextPage: Int) {
        focusedField = nil
        withAnimation(reduceMotion ? nil : .easeInOut) { page = nextPage }
    }
}

#Preview("Onboarding") {
    OnboardingView(viewModel: OnboardingViewModel(goals: (try? JSONGoalRepository().goals) ?? []))
        .environment(ExerciseGuideViewModel(browse: BrowseExerciseGuideUseCase(repository: try! JSONExerciseRepository())))
        .tint(HerLiftTheme.primary)
}

enum OnboardingField: Hashable { case age, height, weight, health, targetWeight }

struct OnboardingPageContent<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            content().frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 44)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(HerLiftTheme.background)
        .foregroundStyle(HerLiftTheme.text)
    }
}

#Preview("Onboarding page") {
    OnboardingPageContent {
        Text("Page content").font(.title2.bold())
    }
}

struct OnboardingNumberField: View {
    let title: String
    @Binding var text: String
    let prompt: String
    var unit: String? = nil
    var focusedField: FocusState<OnboardingField?>.Binding
    let field: OnboardingField
    var keyboard: UIKeyboardType = .decimalPad

    init(_ title: String, text: Binding<String>, prompt: String, unit: String? = nil,
         focusedField: FocusState<OnboardingField?>.Binding, field: OnboardingField,
         keyboard: UIKeyboardType = .decimalPad) {
        self.title = title
        _text = text
        self.prompt = prompt
        self.unit = unit
        self.focusedField = focusedField
        self.field = field
        self.keyboard = keyboard
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            OnboardingStyle.fieldLabel(title)
            HStack(spacing: 6) {
                TextField(title, text: $text, prompt: Text(prompt).foregroundStyle(HerLiftTheme.secondaryText))
                    .font(.headline).keyboardType(keyboard).focused(focusedField, equals: field)
                if let unit { OnboardingStyle.subtitle(unit) }
            }
            .padding(.horizontal, 14).frame(minHeight: 52)
            .background(HerLiftTheme.surface, in: RoundedRectangle(cornerRadius: 12))
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview("Number field") {
    @Previewable @State var text = "29"
    @Previewable @FocusState var focus: OnboardingField?
    OnboardingNumberField("Age", text: $text, prompt: "29", unit: "years", focusedField: $focus, field: .age)
        .padding(20).background(HerLiftTheme.background)
}

enum OnboardingStyle {
    static func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(title).font(.headline).frame(maxWidth: .infinity, minHeight: 30) }
            .buttonStyle(.borderedProminent).buttonBorderShape(.roundedRectangle(radius: 14)).controlSize(.large)
    }
    static func fieldLabel(_ text: String) -> some View {
        Text(text).font(.footnote.weight(.medium)).foregroundStyle(HerLiftTheme.secondaryText)
    }
    static func subtitle(_ text: String) -> some View {
        Text(text).font(.subheadline).foregroundStyle(HerLiftTheme.secondaryText)
    }
    static func helper(_ text: String) -> some View {
        Text(text).font(.footnote).foregroundStyle(HerLiftTheme.secondaryText)
    }
}

let onboardingPreviewGoals = [
    Goal(id: "loseFat", title: "Lose fat", requiresTargetWeight: true),
    Goal(id: "buildMuscle", title: "Build muscle", requiresTargetWeight: false),
    Goal(id: "buildStrength", title: "Get stronger", requiresTargetWeight: false),
    Goal(id: "increaseGymConfidence", title: "Feel confident in the gym", requiresTargetWeight: false)
]
