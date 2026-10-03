import SwiftUI

/// The pause between sets: a countdown, what comes next, and a weight suggestion she can take or leave.
/// It leaves by itself when the time is up.
struct RestView: View {
    let viewModel: WorkoutSessionViewModel
    let rest: WorkoutSessionViewModel.RestState

    @ScaledMetric(relativeTo: .largeTitle) private var countdownSize: CGFloat = 96

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Rest").font(.headline).foregroundStyle(HerLiftTheme.secondaryText)
                Text(timerInterval: Date.now...max(rest.endsAt, Date.now), countsDown: true)
                    .font(.system(size: countdownSize, weight: .bold)).monospacedDigit()
                    .foregroundStyle(HerLiftTheme.text)
                    .minimumScaleFactor(0.5).lineLimit(1)
                if let next = viewModel.restNextLine {
                    Text(next).font(.subheadline).foregroundStyle(HerLiftTheme.secondaryText)
                }
            }
            .padding(.top, 48)
            .accessibilityElement(children: .combine)

            if let suggestion = rest.suggestion { buddyCard(suggestion) }
            Spacer()
            Button("Skip rest") { viewModel.endRest() }
                .font(.subheadline).foregroundStyle(HerLiftTheme.secondaryText)
                .frame(minHeight: 44)
        }
        .padding(.horizontal, 20).padding(.bottom, 16)
        .frame(maxWidth: .infinity)
        // When the time is up, go back to logging the next set.
        .task(id: rest.endsAt) {
            let remaining = rest.endsAt.timeIntervalSinceNow
            if remaining > 0 { try? await Task.sleep(for: .seconds(remaining)) }
            if !Task.isCancelled { viewModel.endRest() }
        }
    }

    private func buddyCard(_ suggestion: NextSetSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(suggestion.message).font(.body).foregroundStyle(HerLiftTheme.text)
            HStack(spacing: 12) {
                Button(suggestion.useTitle) { viewModel.useSuggestion() }
                    .buttonStyle(.borderedProminent).buttonBorderShape(.roundedRectangle(radius: 12))
                    .controlSize(.large)
                Button(suggestion.keepTitle) { viewModel.keepWeight() }
                    .font(.headline).foregroundStyle(HerLiftTheme.text)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HerLiftTheme.surface, in: RoundedRectangle(cornerRadius: 14))
    }
}

#Preview("Rest · with a suggestion") {
    let viewModel = previewSession()
    viewModel.start()
    viewModel.repsText = "8"
    viewModel.effort = .hard
    viewModel.completeSet()
    return NavigationStack {
        if let rest = viewModel.rest { RestView(viewModel: viewModel, rest: rest) }
    }
    .tint(HerLiftTheme.primary)
}

// MARK: - Preview data

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
