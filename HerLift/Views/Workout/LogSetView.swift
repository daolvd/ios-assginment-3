import SwiftUI

/// Logging the current set: exercise, target, weight, reps and how it felt, then Complete set.
/// The caller supplies the NavigationStack.
struct LogSetView: View {
    let viewModel: WorkoutSessionViewModel
    /// Runs once the workout has been saved as finished.
    let onFinished: () -> Void

    @Environment(ExerciseGuideViewModel.self) private var guide
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showsHowTo = false
    @FocusState private var focusedField: Field?

    private enum Field { case weight, reps }

    var body: some View {
        Group {
            if let current = viewModel.current {
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
        .toolbar {
            if let current = viewModel.current {
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
            if let current = viewModel.current {
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
        if viewModel.finish() { onFinished() }
    }
}
