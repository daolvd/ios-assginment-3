import Foundation

/// A notification to remind her of a workout.
nonisolated struct WorkoutReminder: Equatable, Sendable {
    let fireDate: Date
    let title: String
    let body: String
    /// What the reminder's own view shows; nil for a reminder with no workout behind it.
    var content: ReminderContent? = nil
}

/// When and what to remind: 30 minutes before her training time on her next training day, unless that
/// workout is already done.
nonisolated enum WorkoutReminderRule {
    static let leadMinutes = 30
    /// The training time until she picks one: 18:00, as minutes after midnight.
    static let defaultTrainingMinute = 18 * 60
    /// How far ahead to look for her next training day.
    private static let daysAhead = 14

    /// The reminder for the next workout of an accepted plan, or nil when there is none to remind about.
    /// `trainingMinute` is her training time as minutes after midnight.
    static func next(
        for plan: WorkoutPlan, completedDays: Set<Date>, now: Date, trainingMinute: Int,
        calendar: Calendar = .current
    ) -> WorkoutReminder? {
        guard plan.status == .active, let startedOn = plan.startedOn else { return nil }
        let startDay = calendar.startOfDay(for: startedOn)
        let today = calendar.startOfDay(for: now)

        for offset in 0...daysAhead {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today), day >= startDay,
                  let workout = plan.workouts.first(where: {
                      $0.weekday == PlanWeek.mondayBasedWeekday(of: day, calendar: calendar)
                  }),
                  !completedDays.contains(day),
                  let fireDate = calendar.date(byAdding: .minute, value: trainingMinute - leadMinutes, to: day),
                  fireDate > now
            else { continue }
            return reminder(for: workout, at: fireDate)
        }
        return nil
    }

    /// A reminder to try out the notification: the next workout's content, shortly from now.
    static func test(for plan: WorkoutPlan?, now: Date, after seconds: TimeInterval = 5) -> WorkoutReminder {
        let fireDate = now.addingTimeInterval(seconds)
        guard let workout = plan?.workouts.first else {
            return WorkoutReminder(fireDate: fireDate, title: "Workout in \(leadMinutes) minutes", body: "This is how your reminder will look.")
        }
        return reminder(for: workout, at: fireDate)
    }

    /// The title, how long it takes and the first three exercises; the reminder's own view gets the muscle groups,
    /// the start time and the minutes.
    private static func reminder(for workout: PlannedWorkout, at fireDate: Date) -> WorkoutReminder {
        let groups = workout.categoryIDs.map(\.capitalized).joined(separator: " · ")
        let exercises = workout.exercises.prefix(3).map(\.exercise.name).joined(separator: ", ")
        let content = ReminderContent(
            title: groups, minutes: workout.estimatedMinutes,
            startsAt: fireDate.addingTimeInterval(Double(leadMinutes * 60)))
        return WorkoutReminder(
            fireDate: fireDate, title: "Workout in \(leadMinutes) minutes",
            body: "\(groups) · about \(workout.estimatedMinutes) min\n\(exercises)", content: content)
    }
}
