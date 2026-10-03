import Foundation

/// Works out what the widget should show from the plan, today's log and her training time.
nonisolated enum CoachSnapshotBuilder {
    static func make(
        plan: WorkoutPlan?, log: WorkoutLog?, completedDays: Set<Date>, now: Date, trainingMinute: Int,
        calendar: Calendar = .current
    ) -> CoachSnapshot {
        let today = calendar.startOfDay(for: now)
        guard let plan, plan.status == .active else {
            return CoachSnapshot(
                phase: .noPlan, day: today, today: nil, next: nil, week: [], steps: [], loggedSetCount: 0,
                startedAt: nil, summary: nil, updatedAt: now)
        }

        var completed = completedDays
        if log?.status == .completed { completed.insert(today) }
        let week = PlanWeek(plan: plan, today: now, completedDays: completed, calendar: calendar).days.map {
            CoachSnapshot.Day(date: $0.date, isTraining: $0.workout != nil, isDone: $0.state == .done)
        }
        let todaysWorkout = workout(in: plan, on: today, calendar: calendar)
        let todayItem = todaysWorkout.map { item($0, on: today, trainingMinute: trainingMinute, calendar: calendar) }
        let next = nextWorkout(in: plan, after: today, trainingMinute: trainingMinute, calendar: calendar)

        let phase: CoachSnapshot.Phase
        var steps: [CoachSnapshot.Step] = []
        var summary: CoachSnapshot.Summary?
        if let todaysWorkout {
            let todaysLog = log ?? WorkoutLog(date: today, weekday: todaysWorkout.weekday, status: .inProgress, sets: [])
            if completed.contains(today) {
                phase = .done
                summary = log.map(summary(of:))
            } else {
                steps = remainingSteps(of: todaysWorkout, log: todaysLog)
                if log == nil {
                    phase = .ready
                } else {
                    phase = steps.isEmpty ? .allSetsDone : .logging
                }
            }
        } else {
            phase = .restDay
        }

        return CoachSnapshot(
            phase: phase, day: today, today: todayItem, next: next, week: week, steps: steps,
            loggedSetCount: log?.sets.count ?? 0, startedAt: log?.startedAt, summary: summary, updatedAt: now)
    }

    /// Every set not yet logged, in order. A set starts from the weight of the exercise's last logged set,
    /// otherwise from the plan's target weight.
    private static func remainingSteps(of workout: PlannedWorkout, log: WorkoutLog) -> [CoachSnapshot.Step] {
        var steps: [CoachSnapshot.Step] = []
        for (index, planned) in workout.exercises.enumerated() {
            let isBodyweight = planned.exercise.loadType == "bodyweight"
            let weight = isBodyweight ? 0 : (log.sets.last { $0.exerciseID == planned.id }?.weightKg ?? planned.targetWeightKg)
            for setNumber in stride(from: 1, through: planned.sets, by: 1)
            where !log.sets.contains(where: { $0.exerciseID == planned.id && $0.setNumber == setNumber }) {
                steps.append(CoachSnapshot.Step(
                    exerciseID: planned.id, exerciseName: planned.exercise.name,
                    exerciseNumber: index + 1, exerciseCount: workout.exercises.count,
                    setNumber: setNumber, setCount: planned.sets, weightKg: weight, isBodyweight: isBodyweight,
                    minimumReps: planned.exercise.minimumReps, maximumReps: planned.exercise.maximumReps,
                    restSeconds: planned.exercise.defaultRestSeconds))
            }
        }
        return steps
    }

    /// The sets she logged and the minutes from start to finish.
    private static func summary(of log: WorkoutLog) -> CoachSnapshot.Summary {
        var minutes = 0
        if let start = log.startedAt, let end = log.completedAt { minutes = max(1, Int(end.timeIntervalSince(start) / 60)) }
        return CoachSnapshot.Summary(setCount: log.sets.count, minutes: minutes)
    }

    private static func workout(in plan: WorkoutPlan, on day: Date, calendar: Calendar) -> PlannedWorkout? {
        guard let startedOn = plan.startedOn, day >= calendar.startOfDay(for: startedOn) else { return nil }
        let weekday = PlanWeek.mondayBasedWeekday(of: day, calendar: calendar)
        return plan.workouts.first { $0.weekday == weekday }
    }

    /// The next training day after `day`, or nil when the plan has no training day.
    private static func nextWorkout(in plan: WorkoutPlan, after day: Date, trainingMinute: Int, calendar: Calendar)
        -> CoachSnapshot.Workout?
    {
        for offset in 1...7 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: day),
                  let workout = workout(in: plan, on: date, calendar: calendar) else { continue }
            return item(workout, on: date, trainingMinute: trainingMinute, calendar: calendar)
        }
        return nil
    }

    private static func item(_ workout: PlannedWorkout, on day: Date, trainingMinute: Int, calendar: Calendar)
        -> CoachSnapshot.Workout
    {
        CoachSnapshot.Workout(
            title: workout.categoryIDs.map(\.capitalized).joined(separator: " · "),
            minutes: workout.estimatedMinutes,
            startsAt: calendar.date(byAdding: .minute, value: trainingMinute, to: day) ?? day)
    }
}
