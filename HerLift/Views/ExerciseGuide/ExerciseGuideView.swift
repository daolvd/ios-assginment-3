import SwiftUI

/// Searchable list of the catalogue grouped by muscle. The caller supplies the NavigationStack.
struct ExerciseGuideView: View {
    @Environment(ExerciseGuideViewModel.self) private var guideViewModel

    var body: some View {
        @Bindable var viewModel = guideViewModel
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                ForEach(viewModel.sections) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.title).font(.headline).foregroundStyle(HerLiftTheme.text)
                            .accessibilityAddTraits(.isHeader)
                        HLGroup {
                            ForEach(section.exercises) { exercise in
                                NavigationLink {
                                    ExerciseDetailView(exerciseID: exercise.id)
                                } label: {
                                    HLListRow(title: exercise.name, subtitle: subtitle(for: exercise),
                                              accessory: .chevron)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                if viewModel.sections.isEmpty { emptyState }
            }
            .padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(HerLiftTheme.background)
        .navigationTitle("Exercise Guide")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $viewModel.searchText, prompt: "Search exercises")
    }

    private var emptyState: some View {
        VStack(spacing: 4) {
            Text("No exercises found").font(.headline).foregroundStyle(HerLiftTheme.text)
            Text("Try a different name, muscle or equipment.")
                .font(.subheadline).foregroundStyle(HerLiftTheme.secondaryText)
        }
        .frame(maxWidth: .infinity).padding(.top, 48)
        .accessibilityElement(children: .combine)
    }

    private func subtitle(for exercise: Exercise) -> String {
        "\(exercise.equipment.capitalized) · \(exercise.position.capitalized) · \(exercise.minimumReps)–\(exercise.maximumReps) reps"
    }
}

#Preview("Exercise guide") {
    NavigationStack { ExerciseGuideView() }
        .environment(ExerciseGuideViewModel(browse: BrowseExerciseGuideUseCase(repository: try! JSONExerciseRepository())))
        .tint(HerLiftTheme.primary)
}
