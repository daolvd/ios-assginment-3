import SwiftUI

/// Shows the plan built right after onboarding, or why it could not be built.
/// The caller supplies the NavigationStack.
struct GeneratePlanView: View {
    let viewModel: GeneratePlanViewModel
    let onChangeAnswers: () -> Void

    private static let weekdayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                switch viewModel.state {
                case .idle:
                    EmptyView()
                case .ready(let plan):
                    ForEach(plan.workouts) { workout in workoutSection(workout) }
                case .failed(let error):
                    failure(error)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 32)
        }
        .background(HerLiftTheme.background)
        .navigationTitle("Your plan")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink("Guide") { ExerciseGuideView() }
            }
        }
    }

    private func workoutSection(_ workout: PlannedWorkout) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.weekdayNames[workout.weekday - 1]).font(.headline).foregroundStyle(HerLiftTheme.text)
                Text("\(workout.categoryIDs.map(\.capitalized).joined(separator: " · ")) · "
                     + "\(workout.exercises.count) exercises · about \(workout.estimatedMinutes) min")
                    .font(.footnote.weight(.medium)).foregroundStyle(HerLiftTheme.secondaryText)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            HLGroup {
                ForEach(workout.exercises) { planned in
                    NavigationLink {
                        ExerciseDetailView(exerciseID: planned.exercise.id)
                    } label: {
                        HLListRow(
                            title: planned.exercise.name,
                            subtitle: "\(planned.sets) sets · \(planned.exercise.minimumReps)–\(planned.exercise.maximumReps) reps",
                            accessory: .chevron)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func failure(_ error: PlanningError) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HLInlineError(error)
            Button("Change my answers", action: onChangeAnswers)
                .buttonStyle(.borderedProminent).buttonBorderShape(.roundedRectangle(radius: 14))
                .controlSize(.large)
        }
    }
}
