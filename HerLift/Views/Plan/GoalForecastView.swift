import SwiftUI

/// The goal, where she is now, the forecast with its disclaimer, and the milestones of the first weeks.
struct GoalForecastView: View {
    let plan: WorkoutPlan
    let goalTitle: String
    var now = Date()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HLGroup {
                    if let forecast = plan.weightForecast {
                        HLListRow(title: "Now", subtitle: PlanFormatting.kilograms(forecast.currentKg))
                        HLListRow(title: "Target", subtitle: PlanFormatting.kilograms(forecast.targetKg))
                        HLListRow(
                            title: "Forecast",
                            subtitle: "Around \(PlanFormatting.weeks(forecast.earliestWeek, forecast.latestWeek))")
                    } else if let headline = PlanFormatting.forecastHeadline(of: plan) {
                        HLListRow(title: "Forecast", subtitle: headline)
                    }
                }

                Text(ForecastCalculator.disclaimer).font(.footnote).foregroundStyle(HerLiftTheme.secondaryText)

                if !plan.milestones.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Milestones").font(.headline).foregroundStyle(HerLiftTheme.text)
                            .accessibilityAddTraits(.isHeader)
                        ForEach(plan.milestones) { milestone in milestoneRow(milestone) }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 24)
        }
        .background(HerLiftTheme.background)
        .navigationTitle(goalTitle)
        .navigationBarTitleDisplayMode(.large)
    }

    private func milestoneRow(_ milestone: ForecastMilestone) -> some View {
        let isDone = isDone(milestone)
        return HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().strokeBorder(isDone ? HerLiftTheme.text : HerLiftTheme.border, lineWidth: 2)
                    .background(Circle().fill(isDone ? HerLiftTheme.text : Color.clear))
                if isDone {
                    Image(systemName: "checkmark").font(.caption2.weight(.bold)).foregroundStyle(HerLiftTheme.background)
                }
            }
            .frame(width: 22, height: 22)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(PlanFormatting.weeks(milestone.startWeek, milestone.endWeek).capitalized)
                    .font(.footnote).foregroundStyle(HerLiftTheme.secondaryText)
                Text(milestone.title).font(.body).foregroundStyle(HerLiftTheme.text)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(isDone ? "Done" : "Not yet")
    }

    /// A milestone is done once all of its weeks have passed since the plan started.
    private func isDone(_ milestone: ForecastMilestone) -> Bool {
        guard let start = plan.startedOn else { return false }
        let days = Calendar.current.dateComponents([.day], from: start, to: now).day ?? 0
        return days / 7 >= milestone.endWeek
    }
}

#Preview("Goal & forecast") {
    NavigationStack { GoalForecastView(plan: previewPlan(), goalTitle: "Lose fat") }
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
