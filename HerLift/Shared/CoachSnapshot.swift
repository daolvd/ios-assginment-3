import Foundation

/// What the widget shows: the app writes it, the widget only reads it. It is plain data, so the widget never
/// needs the plan, the database or any app code.
nonisolated struct CoachSnapshot: Codable, Equatable, Sendable {
    enum Phase: String, Codable, Sendable {
        /// No accepted plan yet.
        case noPlan
        case restDay
        /// Today's workout is waiting to be started.
        case ready
        /// The workout is started and has sets left.
        case logging
        /// The workout is started and every set is logged; finishing happens in the app.
        case allSetsDone
        case done
    }

    /// A planned workout: "Chest · Core", about 40 minutes, starting at her training time.
    struct Workout: Codable, Equatable, Sendable {
        let title: String
        let minutes: Int
        let startsAt: Date
    }

    /// One day of the current week, Monday to Sunday, for the week strip.
    struct Day: Codable, Equatable, Sendable {
        /// The start of the day.
        let date: Date
        let isTraining: Bool
        let isDone: Bool
    }

    /// One set still to do.
    struct Step: Codable, Equatable, Sendable {
        let exerciseID: String
        let exerciseName: String
        /// Counted from 1 inside the workout.
        let exerciseNumber: Int
        let exerciseCount: Int
        let setNumber: Int
        let setCount: Int
        /// The weight to start from; nil while no weight is known. Always 0 for bodyweight exercises.
        let weightKg: Double?
        let isBodyweight: Bool
        let minimumReps: Int
        let maximumReps: Int
        let restSeconds: Int
    }

    /// What a finished workout came to.
    struct Summary: Codable, Equatable, Sendable {
        let setCount: Int
        let minutes: Int
    }

    let phase: Phase
    /// The start of the day the snapshot describes. A snapshot from another day only shows the schedule.
    let day: Date
    /// Today's workout; nil on a rest day.
    let today: Workout?
    /// The next training day after today.
    let next: Workout?
    let week: [Day]
    /// The sets still to do today, in order: every set while the workout is ready, the rest once it is started.
    let steps: [Step]
    /// Sets already logged in the app today.
    let loggedSetCount: Int
    let startedAt: Date?
    /// When the rest the app is running ends; nil when she is not resting in the app.
    let restEndsAt: Date?
    /// Only once the workout is done.
    let summary: Summary?
    let updatedAt: Date
}

/// What she did on the widget since the app last looked: the start, the sets she finished and the rest. It
/// belongs to one day; a new day starts with an empty inbox.
nonisolated struct WidgetInbox: Codable, Equatable, Sendable {
    struct LoggedSet: Codable, Equatable, Sendable {
        let exerciseID: String
        let setNumber: Int
        let weightKg: Double
        let repetitions: Int
        /// The raw value of the effort; the widget has no way to ask, so it always says "good".
        let effort: String
        let loggedAt: Date
    }

    /// The start of the day the inbox belongs to.
    var day: Date?
    /// When she tapped Start workout on the widget, until the app has started the workout.
    var startedAt: Date?
    var sets: [LoggedSet] = []
    /// When the rest she started on the widget ends, or when she skipped a rest there. Until the app has read it,
    /// it overrides the app's rest.
    var restEndsAt: Date?
}

/// The widget's rules: which screen to show, Start, Complete set and Skip rest. Kept free
/// of WidgetKit so the app's tests can cover them.
nonisolated enum WidgetCoaching {
    static let repetitionRange = 1...100
    static let effort = "good"

    /// The one screen the widget shows.
    enum Screen: Equatable, Sendable {
        case noPlan
        /// The day's workout or the next one, the week strip, and Start workout when today's can be started.
        case schedule(today: CoachSnapshot.Workout?, next: CoachSnapshot.Workout?, canStart: Bool)
        case log(CoachSnapshot.Step, weightKg: Double?)
        case rest(until: Date, next: CoachSnapshot.Step)
        case allSetsDone(title: String, setCount: Int, startedAt: Date?)
        case done(title: String, summary: CoachSnapshot.Summary?, next: CoachSnapshot.Workout?)
    }

    static func screen(_ snapshot: CoachSnapshot?, _ inbox: WidgetInbox, now: Date, calendar: Calendar = .current)
        -> Screen
    {
        guard let snapshot, snapshot.phase != .noPlan else { return .noPlan }
        guard calendar.isDate(snapshot.day, inSameDayAs: now) else {
            // The app has not been opened today: show the next workout it knew about, without Start.
            let next = [snapshot.today, snapshot.next].compactMap { $0 }
                .first { calendar.startOfDay(for: $0.startsAt) >= calendar.startOfDay(for: now) }
            return .schedule(today: nil, next: next, canStart: false)
        }
        let inbox = current(inbox, for: snapshot)
        switch snapshot.phase {
        case .noPlan:
            return .noPlan
        case .restDay:
            return .schedule(today: nil, next: snapshot.next, canStart: false)
        case .done:
            return .done(title: snapshot.today?.title ?? "", summary: snapshot.summary, next: snapshot.next)
        case .allSetsDone:
            return .allSetsDone(
                title: snapshot.today?.title ?? "", setCount: snapshot.loggedSetCount, startedAt: snapshot.startedAt)
        case .ready where inbox.startedAt == nil:
            return .schedule(today: snapshot.today, next: snapshot.next, canStart: !snapshot.steps.isEmpty)
        case .ready, .logging:
            guard let step = currentStep(snapshot, inbox) else {
                return .allSetsDone(
                    title: snapshot.today?.title ?? "", setCount: snapshot.loggedSetCount + inbox.sets.count,
                    startedAt: snapshot.startedAt ?? inbox.startedAt)
            }
            if let restEndsAt = restEnd(snapshot, inbox), restEndsAt > now { return .rest(until: restEndsAt, next: step) }
            return .log(step, weightKg: weight(for: step, inbox))
        }
    }

    /// The inbox for the snapshot's day; one left over from another day counts as empty.
    static func current(_ inbox: WidgetInbox, for snapshot: CoachSnapshot) -> WidgetInbox {
        guard let day = inbox.day, day == snapshot.day else { return WidgetInbox(day: snapshot.day) }
        return inbox
    }

    /// The rest that applies: the one she ran or skipped on the widget, otherwise the one the app is running.
    static func restEnd(_ snapshot: CoachSnapshot, _ inbox: WidgetInbox) -> Date? {
        current(inbox, for: snapshot).restEndsAt ?? snapshot.restEndsAt
    }

    /// Whether the workout is under way on the widget: started in the app, or started on the widget.
    static func isUnderWay(_ snapshot: CoachSnapshot, _ inbox: WidgetInbox) -> Bool {
        snapshot.phase == .logging || (snapshot.phase == .ready && inbox.startedAt != nil)
    }

    /// The set she is on: the first of the snapshot's steps that she has not done on the widget yet.
    static func currentStep(_ snapshot: CoachSnapshot, _ inbox: WidgetInbox) -> CoachSnapshot.Step? {
        guard isUnderWay(snapshot, inbox), snapshot.steps.indices.contains(inbox.sets.count) else { return nil }
        return snapshot.steps[inbox.sets.count]
    }

    /// The weight for the set: the weight she last logged on the widget for the exercise, or the one the app
    /// started from. Nil when no weight is known, which only the app can ask for.
    static func weight(for step: CoachSnapshot.Step, _ inbox: WidgetInbox) -> Double? {
        if step.isBodyweight { return 0 }
        return inbox.sets.last { $0.exerciseID == step.exerciseID }?.weightKg ?? step.weightKg
    }

    /// The set needs a known weight; the widget has no way to ask for one.
    static func canComplete(_ step: CoachSnapshot.Step, _ inbox: WidgetInbox) -> Bool {
        weight(for: step, inbox) != nil
    }

    // MARK: The buttons

    /// Starts today's workout on the widget; the app records it when it next opens.
    static func start(_ snapshot: CoachSnapshot, _ inbox: WidgetInbox, now: Date) -> WidgetInbox {
        var updated = current(inbox, for: snapshot)
        guard snapshot.phase == .ready, updated.startedAt == nil, !snapshot.steps.isEmpty else { return updated }
        updated.startedAt = now
        return updated
    }

    /// Logs the current set as done with the reps she was asked for, the top of its rep range, the same as the app
    /// starts from, and starts the rest; there is no rest after the last set. Reps are not counted on the widget.
    static func complete(_ snapshot: CoachSnapshot, _ inbox: WidgetInbox, now: Date) -> WidgetInbox {
        let inbox = current(inbox, for: snapshot)
        guard let step = currentStep(snapshot, inbox), canComplete(step, inbox),
              let weight = weight(for: step, inbox) else { return inbox }
        var updated = inbox
        updated.sets.append(WidgetInbox.LoggedSet(
            exerciseID: step.exerciseID, setNumber: step.setNumber, weightKg: weight,
            repetitions: step.maximumReps, effort: effort, loggedAt: now))
        let hasNext = snapshot.steps.indices.contains(updated.sets.count)
        updated.restEndsAt = hasNext ? now.addingTimeInterval(Double(step.restSeconds)) : nil
        return updated
    }

    /// Ends the rest now, whether the widget or the app started it.
    static func skipRest(_ snapshot: CoachSnapshot, _ inbox: WidgetInbox, now: Date) -> WidgetInbox {
        var updated = current(inbox, for: snapshot)
        updated.restEndsAt = now
        return updated
    }
}
