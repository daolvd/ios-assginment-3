import SwiftUI

/// One training day: its exercises with sets and reps, and Start workout when the day is today.
/// Each exercise opens its guide. The caller supplies the NavigationStack.
struct WorkoutDayView: View {
    let workout: PlannedWorkout
    /// Only today's workout can be started, so only today's has a session.
    var session: WorkoutSessionViewModel?
    /// Goes straight to the log when the day opens, because the workout was already started.
    var opensLog = false
    /// Runs once the workout has been finished.
    var onFinished: () -> Void = {}

    @State private var showsLogging = false
    @State private var hasOpenedLog = false

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
        .onAppear {
            guard opensLog, !hasOpenedLog, session?.isInProgress == true else { return }
            hasOpenedLog = true
            showsLogging = true
        }
        .navigationDestination(isPresented: $showsLogging) {
            if let session { LogSetView(viewModel: session, onFinished: onFinished) }
        }
    }
}

#Preview("Workout day · today") {
    NavigationStack { WorkoutDayView(workout: previewWorkout(), session: previewSession()) }
        .environment(previewGuide())
        .tint(HerLiftTheme.primary)
}

#Preview("Workout day · another day") {
    NavigationStack { WorkoutDayView(workout: previewWorkout()) }
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
