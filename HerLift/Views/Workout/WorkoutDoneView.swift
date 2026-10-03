import SwiftUI

/// The end of a workout: what she did, the starting weights it showed, and the changes it proposes for next time.
struct WorkoutDoneView: View {
    let viewModel: WorkoutSessionViewModel
    let summary: WorkoutSummary
    let onBack: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Workout done").font(.largeTitle.bold()).foregroundStyle(HerLiftTheme.text)
                        .accessibilityAddTraits(.isHeader)
                    Text(subtitle).font(.subheadline).foregroundStyle(HerLiftTheme.secondaryText)
                }

                if !summary.proposals.isEmpty { proposals }

                ForEach(summary.startingWeights) { starting in
                    Text("Starting weight saved: \(starting.exerciseName) \(NextSetSuggestion.text(starting.weightKg)) kg")
                        .font(.subheadline).foregroundStyle(HerLiftTheme.text)
                }
                if summary.proposals.isEmpty, summary.startingWeights.isEmpty {
                    Text("Nice work. Your plan stays as it is.")
                        .font(.subheadline).foregroundStyle(HerLiftTheme.secondaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 24)
        }
        .safeAreaInset(edge: .bottom) {
            Button("Back to My Plan", action: onBack)
                .font(.headline).foregroundStyle(HerLiftTheme.primary)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(HerLiftTheme.background)
        }
    }

    private var subtitle: String {
        var parts = [summary.title]
        if let minutes = summary.minutes { parts.append("\(minutes) min") }
        parts.append(summary.setCount == 1 ? "1 set" : "\(summary.setCount) sets")
        return parts.joined(separator: " · ")
    }

    private var proposals: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Next time · \(summary.proposals.count) \(summary.proposals.count == 1 ? "change" : "changes")")
                .font(.headline).foregroundStyle(HerLiftTheme.text)
                .accessibilityAddTraits(.isHeader)

            HLGroup {
                ForEach(summary.proposals) { proposal in
                    HLProposalRow(
                        exercise: proposal.exerciseName, change: proposal.changeText,
                        state: state(of: proposal),
                        onApply: { viewModel.apply(proposal) }, onKeep: { viewModel.keep(proposal) })
                }
            }

            if !viewModel.pendingProposals.isEmpty {
                HStack(spacing: 12) {
                    OnboardingStyle.primaryButton("Apply all") { viewModel.applyAll() }
                    Button { viewModel.keepAll() } label: {
                        Text("Keep all").font(.headline).foregroundStyle(HerLiftTheme.text)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(HerLiftTheme.surface, in: RoundedRectangle(cornerRadius: 14))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            Text("Your plan only changes for the ones you apply.")
                .font(.footnote).foregroundStyle(HerLiftTheme.secondaryText)
                .frame(maxWidth: .infinity)
        }
    }

    private func state(of proposal: WeightProposal) -> HLProposalRow.State {
        switch viewModel.decisions[proposal.id] {
        case .applied: .applied
        case .kept: .kept
        case nil: .pending
        }
    }
}

#Preview("Workout done") {
    let viewModel = previewSession()
    viewModel.start()
    logEverySet(viewModel)
    viewModel.finish()
    return NavigationStack {
        if let summary = viewModel.summary { WorkoutDoneView(viewModel: viewModel, summary: summary, onBack: {}) }
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
