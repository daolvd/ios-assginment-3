import SwiftUI

/// The plan built right after onboarding, waiting for her decision: one row per workout, the forecast,
/// and Accept plan / Start over. The caller supplies the NavigationStack.
struct GeneratePlanView: View {
    let viewModel: GeneratePlanViewModel
    let onAccepted: () -> Void
    let onChangeAnswers: () -> Void

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle:
                Color.clear
            case .ready(let plan):
                planContent(plan)
            case .failed(let error):
                failure(error)
            }
        }
        .background(HerLiftTheme.background)
        .navigationTitle("Your plan")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink("Guide") { ExerciseGuideView() }
            }
        }
        .alert(
            viewModel.error?.errorDescription ?? "Something went wrong",
            isPresented: Binding(get: { viewModel.error != nil }, set: { if !$0 { viewModel.error = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.error?.recoverySuggestion ?? "")
        }
    }

    private func planContent(_ plan: WorkoutPlan) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(PlanFormatting.summary(of: plan)).font(.subheadline).foregroundStyle(HerLiftTheme.secondaryText)

                HLGroup {
                    ForEach(plan.workouts) { workout in
                        NavigationLink {
                            WorkoutDayView(workout: workout)
                        } label: {
                            HLListRow(
                                title: "\(PlanFormatting.weekdayName(workout.weekday)) · \(PlanFormatting.categories(workout))",
                                subtitle: PlanFormatting.preview(of: workout), accessory: .chevron)
                        }
                        .buttonStyle(.plain)
                    }
                }

                forecast(plan)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 24)
        }
        .safeAreaInset(edge: .bottom) {
            if plan.status == .draft { draftActions }
        }
    }

    @ViewBuilder
    private func forecast(_ plan: WorkoutPlan) -> some View {
        if let headline = PlanFormatting.forecastHeadline(of: plan) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Forecast").font(.footnote.weight(.medium)).foregroundStyle(HerLiftTheme.secondaryText)
                Text(headline).font(.headline).foregroundStyle(HerLiftTheme.text)
                Text(ForecastCalculator.disclaimer).font(.caption).foregroundStyle(HerLiftTheme.secondaryText)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var draftActions: some View {
        VStack(spacing: 12) {
            OnboardingStyle.primaryButton("Accept plan") { if viewModel.accept() { onAccepted() } }
            Button {
                if viewModel.startOver() { onChangeAnswers() }
            } label: {
                Text("Start over").font(.headline).foregroundStyle(HerLiftTheme.text)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(HerLiftTheme.surface, in: RoundedRectangle(cornerRadius: 14))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20).padding(.bottom, 12).padding(.top, 8)
        .background(HerLiftTheme.background)
    }

    private func failure(_ error: PlanningError) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HLInlineError(error)
            Button("Change my answers", action: onChangeAnswers)
                .buttonStyle(.borderedProminent).buttonBorderShape(.roundedRectangle(radius: 14))
                .controlSize(.large)
            Spacer()
        }
        .padding(.horizontal, 20).padding(.top, 4)
    }
}

#Preview("Plan ready") {
    NavigationStack { GeneratePlanView(viewModel: previewGeneratePlan(ready: true), onAccepted: {}, onChangeAnswers: {}) }
        .environment(previewGuide())
        .tint(HerLiftTheme.primary)
}

// MARK: - Preview data

/// The goals from the bundled catalogue.
@MainActor
private func previewGoals() -> [Goal] { (try? JSONGoalRepository().goals) ?? [] }

@MainActor
private func previewGuide() -> ExerciseGuideViewModel {
    ExerciseGuideViewModel(browse: BrowseExerciseGuideUseCase(repository: try! JSONExerciseRepository()))
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
