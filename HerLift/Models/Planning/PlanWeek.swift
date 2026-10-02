import Foundation

/// The seven days, Monday to Sunday, of the calendar week that contains today, laid out for My Plan.
nonisolated struct PlanWeek: Equatable, Sendable {
    static let totalWeeks = 12

    struct Day: Equatable, Identifiable, Sendable {
        enum State: Equatable, Sendable {
            case done
            case today
            /// A workout day that is not today and has not been done.
            case upcoming
            case rest
        }

        let date: Date
        /// Monday = 1 … Sunday = 7.
        let weekday: Int
        let workout: PlannedWorkout?
        let state: State

        var id: Int { weekday }
    }

    /// Counted from the day the plan started, between 1 and `totalWeeks`.
    let weekNumber: Int
    let days: [Day]

    var workoutCount: Int { days.filter { $0.workout != nil }.count }
    var doneCount: Int { days.filter { $0.state == .done }.count }

    /// `completedDays` holds the start of each day she finished a workout. Days before the plan started
    /// belong to no workout, so a plan accepted midweek shows the earlier days as rest.
    init(plan: WorkoutPlan, today: Date, completedDays: Set<Date> = [], calendar: Calendar = .current) {
        let todayStart = calendar.startOfDay(for: today)
        let startDay = plan.startedOn.map { calendar.startOfDay(for: $0) } ?? todayStart
        let elapsedDays = calendar.dateComponents([.day], from: startDay, to: todayStart).day ?? 0
        weekNumber = min(max(elapsedDays / 7 + 1, 1), Self.totalWeeks)

        let todayWeekday = Self.mondayBasedWeekday(of: todayStart, calendar: calendar)
        let monday = calendar.date(byAdding: .day, value: 1 - todayWeekday, to: todayStart) ?? todayStart

        days = (1...7).map { weekday in
            let date = calendar.date(byAdding: .day, value: weekday - 1, to: monday) ?? monday
            let workout = date >= startDay ? plan.workouts.first { $0.weekday == weekday } : nil
            let state: Day.State
            if workout == nil {
                state = .rest
            } else if completedDays.contains(date) {
                state = .done
            } else {
                state = date == todayStart ? .today : .upcoming
            }
            return Day(date: date, weekday: weekday, workout: workout, state: state)
        }
    }

    /// Monday = 1 … Sunday = 7, whatever the calendar's first weekday is.
    static func mondayBasedWeekday(of date: Date, calendar: Calendar) -> Int {
        (calendar.component(.weekday, from: date) + 5) % 7 + 1
    }
}
