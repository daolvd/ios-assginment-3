import SwiftUI

/// The exercises of one training day, with sets and reps. Each opens its guide.
struct WorkoutDayView: View {
    let workout: PlannedWorkout

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("\(PlanFormatting.categories(workout)) · \(workout.exercises.count) exercises · about \(workout.estimatedMinutes) min")
                    .font(.subheadline).foregroundStyle(HerLiftTheme.secondaryText)

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
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 24)
        }
        .background(HerLiftTheme.background)
        .navigationTitle(PlanFormatting.weekdayName(workout.weekday))
        .navigationBarTitleDisplayMode(.large)
    }
}
