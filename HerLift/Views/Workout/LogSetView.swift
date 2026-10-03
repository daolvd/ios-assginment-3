import SwiftUI

/// Logging the current set: exercise, target, weight, reps and how it felt, then Complete set.
/// The caller supplies the NavigationStack.
struct LogSetView: View {
    let viewModel: WorkoutSessionViewModel
    /// Runs when she leaves the workout summary.
    let onFinished: () -> Void

    @Environment(ExerciseGuideViewModel.self) private var guide
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showsHowTo = false
    @FocusState private var focusedField: Field?

    private enum Field { case weight, reps }

    var body: some View {
        Group {
            if let summary = viewModel.summary {
                WorkoutDoneView(viewModel: viewModel, summary: summary, onBack: onFinished)
            } else if let rest = viewModel.rest {
                RestView(viewModel: viewModel, rest: rest)
            } else if let current = viewModel.current {
                logging(current)
            } else if viewModel.isReadyToFinish {
                allSetsDone
            } else {
                Color.clear
            }
        }
        .background(HerLiftTheme.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .navigationBarBackButtonHidden(viewModel.summary != nil)
        .toolbar {
            if viewModel.summary == nil, viewModel.rest == nil, let current = viewModel.current {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("How to") { showsHowTo = true }.font(.headline).accessibilityLabel("How to do \(current.exercise.name)")
                }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
        .sheet(isPresented: $showsHowTo) {
            if viewModel.summary == nil, viewModel.rest == nil, let current = viewModel.current {
                NavigationStack {
                    ExerciseDetailView(exerciseID: current.exercise.id)
                        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { showsHowTo = false } } }
                }
                .tint(HerLiftTheme.primary)
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

    // MARK: The set being logged

    private func logging(_ current: WorkoutExercise) -> some View {
        @Bindable var viewModel = viewModel
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    if let progress = viewModel.progressLine {
                        Text(progress).font(.footnote.weight(.medium)).foregroundStyle(HerLiftTheme.secondaryText)
                    }
                    Text(current.exercise.name).font(.largeTitle.bold()).foregroundStyle(HerLiftTheme.text)
                        .accessibilityAddTraits(.isHeader)
                    if let target = viewModel.targetLine {
                        Text(target).font(.subheadline).foregroundStyle(HerLiftTheme.secondaryText)
                    }
                    if let hint = viewModel.weightHint {
                        Text(hint).font(.subheadline.weight(.medium)).foregroundStyle(HerLiftTheme.text)
                            .padding(.top, 4)
                    }
                }

                media(for: current.exercise)
                if let cue = viewModel.cue { Text(cue).font(.subheadline).foregroundStyle(HerLiftTheme.text) }

                HStack(alignment: .top, spacing: 12) {
                    if viewModel.showsWeightField {
                        HLLargeNumberField(
                            title: "Weight", text: $viewModel.weightText, unit: "kg",
                            hasError: viewModel.weightMessage != nil)
                            .focused($focusedField, equals: .weight)
                    }
                    HLLargeNumberField(
                        title: "Reps", text: $viewModel.repsText, unit: "reps",
                        hasError: viewModel.repsMessage != nil, keyboard: .numberPad)
                        .focused($focusedField, equals: .reps)
                }
                if let message = viewModel.repsMessage ?? viewModel.weightMessage { HLInlineError(message) }

                Text("How did it feel?").font(.headline).foregroundStyle(HerLiftTheme.text)
                effortPicker
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 16)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                OnboardingStyle.primaryButton("Complete set") {
                    focusedField = nil
                    viewModel.completeSet()
                }
                .disabled(!viewModel.canCompleteSet)
                Button("Finish workout") { finish() }
                    .font(.subheadline).foregroundStyle(HerLiftTheme.secondaryText)
                    .frame(minHeight: 44)
                    .disabled(!viewModel.hasLoggedSets)
            }
            .padding(.horizontal, 20).padding(.bottom, 8).padding(.top, 8)
            .background(HerLiftTheme.background)
        }
    }

    /// The four efforts side by side, or stacked at accessibility text sizes.
    @ViewBuilder
    private var effortPicker: some View {
        @Bindable var viewModel = viewModel
        if dynamicTypeSize.isAccessibilitySize {
            HLChipPicker(selection: $viewModel.effort, options: PerceivedEffort.allCases) { $0.title }
        } else {
            HStack(spacing: 8) {
                ForEach(PerceivedEffort.allCases, id: \.self) { effort in
                    HLChip(title: effort.title, isSelected: viewModel.effort == effort, horizontalPadding: 4) {
                        viewModel.effort = effort
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func media(for exercise: Exercise) -> some View {
        if let url = guide.videoURL(for: exercise) {
            ExerciseVideoView(url: url)
                .frame(maxWidth: .infinity).frame(height: 168)
                .background(HerLiftTheme.mediaBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(HerLiftTheme.border))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Demonstration: \(exercise.coachingCues.first ?? exercise.name)")
        }
    }

    // MARK: Every set done

    private var allSetsDone: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("All sets done").font(.largeTitle.bold()).foregroundStyle(HerLiftTheme.text)
            Text("Finish to save today's workout.").font(.subheadline).foregroundStyle(HerLiftTheme.secondaryText)
            Spacer()
            OnboardingStyle.primaryButton("Finish workout") { finish() }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 12)
    }

    private func finish() {
        focusedField = nil
        viewModel.finish()
    }
}

#Preview("Log a set") {
    let viewModel = previewSession()
    viewModel.start()
    return NavigationStack { LogSetView(viewModel: viewModel, onFinished: {}) }
        .environment(previewGuide())
        .tint(HerLiftTheme.primary)
}

#Preview("Log a set · all sets done") {
    let viewModel = previewSession()
    viewModel.start()
    logEverySet(viewModel)
    return NavigationStack { LogSetView(viewModel: viewModel, onFinished: {}) }
        .environment(previewGuide())
        .tint(HerLiftTheme.primary)
}

// MARK: - Preview data

@MainActor
private func previewGuide() -> ExerciseGuideViewModel {
    ExerciseGuideViewModel(browse: BrowseExerciseGuideUseCase(repository: try! JSONExerciseRepository()))
}

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

/// The plan kept in memory.
@MainActor
private final class PreviewPlanStore: WorkoutPlanRepository {
    private var plan: WorkoutPlan?
    init(_ plan: WorkoutPlan? = nil) { self.plan = plan }
    func loadPlan() throws -> WorkoutPlan? { plan }
    func savePlan(_ plan: WorkoutPlan) throws { self.plan = plan }
    func deletePlan() throws { plan = nil }
}

/// Workouts kept in memory.
@MainActor
private final class PreviewSessionStore: WorkoutSessionRepository {
    private var logs: [Date: WorkoutLog] = [:]
    func log(on day: Date) throws -> WorkoutLog? { logs[day] }
    func save(_ log: WorkoutLog) throws { logs[log.date] = log }
    func completedDays() throws -> Set<Date> { Set(logs.values.filter { $0.status == .completed }.map(\.date)) }
}

/// Today's workout session, kept in memory.
@MainActor
private func previewSession() -> WorkoutSessionViewModel {
    let viewModel = WorkoutSessionViewModel(
        workout: previewWorkout(), useCase: WorkoutSessionUseCase(sessions: PreviewSessionStore()),
        editPlan: EditWorkoutPlanUseCase(plans: PreviewPlanStore(previewPlan()), exercises: try! JSONExerciseRepository()))
    viewModel.load()
    return viewModel
}

/// Logs every set of the session at 20 kg × 12, felt easy.
@MainActor
private func logEverySet(_ viewModel: WorkoutSessionViewModel) {
    while viewModel.current != nil {
        if viewModel.showsWeightField { viewModel.weightText = "20" }
        viewModel.repsText = "12"
        viewModel.effort = .easy
        viewModel.completeSet()
        viewModel.endRest()
    }
}
