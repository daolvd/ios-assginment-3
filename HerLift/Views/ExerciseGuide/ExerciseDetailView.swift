import SwiftUI

/// Teaches one exercise: demonstration clip, steps, cues to follow and mistakes to avoid.
/// It needs only the exercise ID and reads the catalogue from the environment, so any screen can open it.
/// The steps start collapsed so the clip, cues and mistakes fit on one screen at standard text sizes.
struct ExerciseDetailView: View {
    let exerciseID: Exercise.ID

    @Environment(ExerciseGuideViewModel.self) private var viewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .footnote) private var markerWidth: CGFloat = 18
    @ScaledMetric(relativeTo: .footnote) private var stepDotSize: CGFloat = 22
    @State private var showsSteps = false

    /// Width-to-height ratio of the clip. It keeps the middle 90% of each 16:9 clip,
    /// which holds the whole lifter and machine in every bundled demonstration.
    private let mediaAspectRatio: CGFloat = 0.9 * 16 / 9

    var body: some View {
        Group {
            switch viewModel.exercise(id: exerciseID) {
            case .success(let exercise):
                content(for: exercise)
            case .failure(let error):
                HLInlineError(error).padding(20)
            }
        }
        .background(HerLiftTheme.background)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func content(for exercise: Exercise) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name).font(.title.bold()).foregroundStyle(HerLiftTheme.text)
                        .accessibilityAddTraits(.isHeader)
                    Text([exercise.muscleGroup, exercise.equipment.capitalized, exercise.position.capitalized]
                        .joined(separator: " · "))
                        .font(.footnote).foregroundStyle(HerLiftTheme.secondaryText)
                }

                media(for: exercise)
                steps(for: exercise)

                list("Cues", items: exercise.coachingCues) { _ in
                    Image(systemName: "checkmark").font(.caption.weight(.semibold))
                        .foregroundStyle(HerLiftTheme.primary)
                } accessibilityLabel: { _, cue in "Cue: \(cue)" }

                list("Avoid", items: exercise.commonMistakes) { _ in
                    Image(systemName: "xmark").font(.caption.weight(.semibold))
                        .foregroundStyle(HerLiftTheme.text)
                } accessibilityLabel: { _, mistake in "Avoid: \(mistake)" }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20).padding(.bottom, 16)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    @ViewBuilder
    private func media(for exercise: Exercise) -> some View {
        if let url = viewModel.videoURL(for: exercise) {
            ExerciseVideoView(url: url, fillsFrame: true)
                .aspectRatio(mediaAspectRatio, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .background(HerLiftTheme.mediaBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(HerLiftTheme.border))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Demonstration: \(exercise.coachingCues.first ?? exercise.name)")
        } else {
            HLIllustrationCard(caption: exercise.coachingCues.first ?? exercise.name)
        }
    }

    /// Collapsible card: the header shows the step count and a tap reveals the numbered steps.
    @ViewBuilder
    private func steps(for exercise: Exercise) -> some View {
        if !exercise.instructions.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { showsSteps.toggle() }
                } label: {
                    HStack(spacing: 8) {
                        Text("How to do it").font(.subheadline.weight(.semibold))
                            .foregroundStyle(HerLiftTheme.text)
                        Spacer(minLength: 8)
                        Text("\(exercise.instructions.count) steps").font(.footnote)
                            .foregroundStyle(HerLiftTheme.secondaryText)
                        Image(systemName: "chevron.down").font(.footnote.weight(.semibold))
                            .foregroundStyle(HerLiftTheme.secondaryText)
                            .rotationEffect(.degrees(showsSteps ? 180 : 0))
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("How to do it, \(exercise.instructions.count) steps")
                .accessibilityValue(showsSteps ? "Expanded" : "Collapsed")
                .accessibilityHint(showsSteps ? "Hides the steps" : "Shows the steps")

                if showsSteps {
                    Divider().overlay(HerLiftTheme.border)
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(exercise.instructions.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text("\(index + 1)").font(.caption.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(HerLiftTheme.onPrimary)
                                    .frame(width: stepDotSize, height: stepDotSize)
                                    .background(HerLiftTheme.primary, in: Circle())
                                    .accessibilityHidden(true)
                                Text(step).font(.footnote).foregroundStyle(HerLiftTheme.text)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Step \(index + 1). \(step)")
                        }
                    }
                    .padding(16)
                    .transition(.opacity)
                }
            }
            .background(HerLiftTheme.surface, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    /// A titled list where each line starts with a small marker (tick or cross).
    @ViewBuilder
    private func list<Marker: View>(
        _ title: String, items: [String],
        @ViewBuilder marker: @escaping (Int) -> Marker,
        accessibilityLabel: @escaping (Int, String) -> String
    ) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(HerLiftTheme.text)
                    .accessibilityAddTraits(.isHeader)
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        marker(index).frame(minWidth: markerWidth, alignment: .leading)
                            .accessibilityHidden(true)
                        Text(item).font(.footnote).foregroundStyle(HerLiftTheme.text)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(accessibilityLabel(index, item))
                }
            }
        }
    }
}

#Preview("Exercise detail") {
    NavigationStack { ExerciseDetailView(exerciseID: "machine-chest-press") }
        .environment(ExerciseGuideViewModel(browse: BrowseExerciseGuideUseCase(repository: try! JSONExerciseRepository())))
        .tint(HerLiftTheme.primary)
}
