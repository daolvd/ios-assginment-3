import Foundation

/// Plain-text wording shared by the plan screens.
enum PlanFormatting {
    private static let weekdayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    static func weekdayName(_ weekday: Int) -> String {
        weekdayNames.indices.contains(weekday - 1) ? weekdayNames[weekday - 1] : "Day \(weekday)"
    }

    /// "MON" for Monday.
    static func shortWeekdayName(_ weekday: Int) -> String {
        String(weekdayName(weekday).prefix(3)).uppercased()
    }

    /// "3 exercises · 45 min"
    static func meta(of workout: PlannedWorkout) -> String {
        "\(workout.exercises.count) exercises · \(workout.estimatedMinutes) min"
    }

    /// "Target 56 kg · see forecast"
    static func goalSubtitle(of plan: WorkoutPlan) -> String {
        guard let forecast = plan.weightForecast else { return "See forecast and milestones" }
        return "Target \(kilograms(forecast.targetKg)) · see forecast"
    }

    static func categories(_ workout: PlannedWorkout) -> String {
        workout.categoryIDs.map(\.capitalized).joined(separator: " · ")
    }

    static func kilograms(_ value: Double) -> String {
        value.rounded() == value ? "\(Int(value)) kg" : String(format: "%.1f kg", value)
    }

    /// "week 6" or "week 6–12".
    static func weeks(_ first: Int, _ last: Int) -> String {
        first == last ? "week \(first)" : "week \(first)–\(last)"
    }

    /// "3 workouts a week · about 37–43 min each"
    static func summary(of plan: WorkoutPlan) -> String {
        let minutes = plan.workouts.map(\.estimatedMinutes)
        guard let shortest = minutes.min(), let longest = minutes.max() else { return "" }
        let length = shortest == longest ? "\(shortest)" : "\(shortest)–\(longest)"
        return "\(plan.workouts.count) workouts a week · about \(length) min each"
    }

    /// "Leg Press, Glute Bridge +1"
    static func preview(of workout: PlannedWorkout) -> String {
        let names = workout.exercises.prefix(2).map(\.exercise.name).joined(separator: ", ")
        let more = workout.exercises.count - 2
        return more > 0 ? "\(names) +\(more)" : names
    }

    /// The forecast headline: the weight she is heading for, or the plan's last milestone.
    static func forecastHeadline(of plan: WorkoutPlan) -> String? {
        if let forecast = plan.weightForecast {
            return "Reach \(kilograms(forecast.targetKg)) around \(weeks(forecast.earliestWeek, forecast.latestWeek))"
        }
        guard let last = plan.milestones.last else { return nil }
        return "\(last.title) around \(weeks(last.startWeek, last.endWeek))"
    }
}
