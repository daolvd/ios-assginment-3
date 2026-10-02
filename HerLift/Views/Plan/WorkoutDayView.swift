import SwiftUI

/// One training day: its exercises with sets and reps, and Start workout when the day is today.
/// Each exercise opens its guide. The caller supplies the NavigationStack.
struct WorkoutDayView: View {
    let workout: PlannedWorkout
    /// Only today's workout can be started, so only today's has a session.
    var session: WorkoutSessionViewModel?
    /// Runs once the workout has been finished.
    var onFinished: () -> Void = {}

    @State private var showsLogging = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    // A no-break space keeps each "·" with the word before it when the title wraps.
                    Text(PlanFormatting.categories(workout).replacingOccurrences(of: " · ", with: "\u{00A0}· "))
                        .font(.largeTitle.bold())
                        .foregroundStyle(HerLiftTheme.text)
                        .accessibilityAddTraits(.isHeader)
                    Text(PlanFormatting.workoutHeader(of: workout, isToday: session != nil))
                        .font(.subheadline).foregroundStyle(HerLiftTheme.secondaryText)
                }

                HLGroup {
                    ForEach(workout.exercises) { planned in
                        NavigationLink {
                            ExerciseDetailView(exerciseID: planned.exercise.id)
                        } label: {
                            HLListRow(
                                title: planned.exercise.name, subtitle: PlanFormatting.target(of: planned),
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom) {
            if let session {
                OnboardingStyle.primaryButton(session.buttonTitle) {
                    if session.start() { showsLogging = true }
                }
                .disabled(session.isFinished)
                .padding(.horizontal, 20).padding(.bottom, 12).padding(.top, 8)
                .background(HerLiftTheme.background)
            }
        }
        .navigationDestination(isPresented: $showsLogging) {
            if let session { LogSetView(viewModel: session, onFinished: onFinished) }
        }
    }
}
