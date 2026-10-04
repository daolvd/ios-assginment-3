import SwiftUI
import WidgetKit

/// The Lock Screen version of the workout widget: the same screens as the Home Screen widget in a small
/// rectangle, with nothing to tap. Lock Screen widgets are drawn in one tint, so this is text only.
struct LockScreenWidgetView: View {
    let screen: WidgetCoaching.Screen
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            switch screen {
            case .noPlan:
                headline("HerLift")
                detail("Build your plan in the app.")
            case .schedule(let today, let next, _):
                schedule(today: today, next: next)
            case .log(let step, let weightKg):
                caption("Set \(step.setNumber) of \(step.setCount)")
                headline(step.exerciseName)
                detail(target(step, weightKg))
            case .rest(let until, let next):
                caption("REST")
                Text(timerInterval: now...max(now, until), countsDown: true)
                    .font(.system(size: 28, weight: .bold)).monospacedDigit()
                detail("Next: set \(next.setNumber) of \(next.setCount)")
            case .allSetsDone:
                headline("All sets done")
                detail("Open HerLift to finish.")
            case .done(_, _, let next):
                headline("Workout done")
                if let next { detail("Next: \(nextLine(next))") }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func schedule(today: CoachSnapshot.Workout?, next: CoachSnapshot.Workout?) -> some View {
        if let today {
            caption("TODAY · \(today.startsAt.formatted(date: .omitted, time: .shortened))")
            headline(today.title)
            detail("About \(today.minutes) min")
        } else if let next {
            caption("REST DAY")
            headline(next.title)
            detail("Next: \(nextLine(next))")
        } else {
            headline("Rest day")
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text).font(.caption2.weight(.semibold)).lineLimit(1)
    }

    private func headline(_ text: String) -> some View {
        Text(text).font(.headline).lineLimit(1).minimumScaleFactor(0.7)
    }

    private func detail(_ text: String) -> some View {
        Text(text).font(.caption).lineLimit(1).minimumScaleFactor(0.8)
    }

    /// "20 kg × 12 reps", "Bodyweight × 12 reps", or "Find your weight" until a weight is known.
    private func target(_ step: CoachSnapshot.Step, _ weightKg: Double?) -> String {
        if step.isBodyweight { return "Bodyweight × \(step.maximumReps) reps" }
        guard let weightKg else { return "Find your weight" }
        let text = weightKg.rounded() == weightKg ? "\(Int(weightKg))" : String(format: "%.1f", weightKg)
        return "\(text) kg × \(step.maximumReps) reps"
    }

    /// "Wed · Legs · 6:00 PM"
    private func nextLine(_ workout: CoachSnapshot.Workout) -> String {
        let day = workout.startsAt.formatted(.dateTime.weekday(.abbreviated))
        return "\(day) · \(workout.title) · \(workout.startsAt.formatted(date: .omitted, time: .shortened))"
    }
}

// MARK: - Previews

#Preview("Lock Screen · schedule", as: .accessoryRectangular) {
    HerLiftWidget()
} timeline: {
    lockEntry(.ready)
}

#Preview("Lock Screen · log a set", as: .accessoryRectangular) {
    HerLiftWidget()
} timeline: {
    lockEntry(.logging)
}

#Preview("Lock Screen · rest", as: .accessoryRectangular) {
    HerLiftWidget()
} timeline: {
    lockEntry(.logging, restEndsIn: 45)
}

#Preview("Lock Screen · all sets done", as: .accessoryRectangular) {
    HerLiftWidget()
} timeline: {
    lockEntry(.allSetsDone)
}

#Preview("Lock Screen · workout done", as: .accessoryRectangular) {
    HerLiftWidget()
} timeline: {
    lockEntry(.done)
}

#Preview("Lock Screen · no plan", as: .accessoryRectangular) {
    HerLiftWidget()
} timeline: {
    CoachEntry(date: Date(), snapshot: nil, inbox: WidgetInbox())
}

// MARK: - Preview data

/// Today's Chest · Core workout at 6:00 PM in the given phase; the chest press is next, with a rest running when
/// `restEndsIn` seconds are given.
private func lockEntry(_ phase: CoachSnapshot.Phase, restEndsIn seconds: Double? = nil) -> CoachEntry {
    let calendar = Calendar.current
    let now = Date()
    let today = calendar.startOfDay(for: now)
    let sixPM = calendar.date(byAdding: .minute, value: 18 * 60, to: today)!
    let steps = (2...3).map {
        CoachSnapshot.Step(
            exerciseID: "machine-chest-press", exerciseName: "Machine Chest Press", exerciseNumber: 1,
            exerciseCount: 2, setNumber: $0, setCount: 3, weightKg: 20, isBodyweight: false, minimumReps: 10,
            maximumReps: 12, restSeconds: 90)
    }
    let snapshot = CoachSnapshot(
        phase: phase, day: today,
        today: CoachSnapshot.Workout(title: "Chest · Core", minutes: 40, startsAt: sixPM),
        next: CoachSnapshot.Workout(title: "Legs", minutes: 45, startsAt: sixPM.addingTimeInterval(4 * 24 * 3600)),
        week: [], steps: phase == .ready || phase == .logging ? steps : [], loggedSetCount: phase == .ready ? 0 : 5,
        startedAt: phase == .ready ? nil : now.addingTimeInterval(-32 * 60),
        restEndsAt: seconds.map { now.addingTimeInterval($0) },
        summary: phase == .done ? CoachSnapshot.Summary(setCount: 5, minutes: 43) : nil, updatedAt: now)
    return CoachEntry(date: now, snapshot: snapshot, inbox: WidgetInbox(day: today))
}
