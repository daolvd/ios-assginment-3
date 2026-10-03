import AppIntents
import WidgetKit
import SwiftUI

struct CoachEntry: TimelineEntry {
    let date: Date
    let snapshot: CoachSnapshot?
    let inbox: WidgetInbox
}

struct CoachProvider: TimelineProvider {
    func placeholder(in context: Context) -> CoachEntry {
        CoachEntry(date: Date(), snapshot: nil, inbox: WidgetInbox())
    }

    func getSnapshot(in context: Context, completion: @escaping (CoachEntry) -> Void) {
        completion(entry(at: Date()))
    }

    /// The widget changes when the app publishes and when she taps a button; on its own it only changes when a
    /// rest ends and at midnight, when the day's workout no longer applies.
    func getTimeline(in context: Context, completion: @escaping (Timeline<CoachEntry>) -> Void) {
        let now = Date()
        let midnight = Calendar.current.startOfDay(for: now.addingTimeInterval(24 * 60 * 60))
        var entries = [entry(at: now)]
        if let restEndsAt = entries[0].inbox.restEndsAt, restEndsAt > now, restEndsAt < midnight {
            entries.append(entry(at: restEndsAt))
        }
        entries.append(entry(at: midnight))
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func entry(at date: Date) -> CoachEntry {
        CoachEntry(date: date, snapshot: CoachFiles.readSnapshot(), inbox: CoachFiles.readInbox())
    }
}

struct HerLiftWidget: Widget {
    let kind = "HerLiftWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CoachProvider()) { entry in
            CoachWidgetView(entry: entry)
                .containerBackground(WidgetTheme.background, for: .widget)
        }
        .configurationDisplayName("Workout")
        .description("See your week, start today's workout and log your sets from the Home Screen.")
        .supportedFamilies([.systemMedium])
    }
}

/// Picks the screen for the entry. Tapping outside a button opens today's workout in the app.
struct CoachWidgetView: View {
    let entry: CoachEntry

    var body: some View {
        screen
            .widgetURL(WorkoutLink.today)
    }

    @ViewBuilder
    private var screen: some View {
        switch WidgetCoaching.screen(entry.snapshot, entry.inbox, now: entry.date) {
        case .noPlan:
            NoPlanWidgetView()
        case .schedule(let today, let next, let canStart):
            ScheduleWidgetView(
                today: today, next: next, canStart: canStart, week: entry.snapshot?.week ?? [], now: entry.date)
        case .log(let step, let weightKg, let reps):
            LogSetWidgetView(step: step, weightKg: weightKg, reps: reps)
        case .rest(let until, let next):
            RestWidgetView(until: until, next: next, now: entry.date)
        case .allSetsDone(let title, let setCount, let startedAt):
            AllSetsDoneWidgetView(title: title, setCount: setCount, startedAt: startedAt, now: entry.date)
        case .done(let title, let summary, let next):
            WorkoutDoneWidgetView(title: title, summary: summary, next: next)
        }
    }
}

#Preview("Workout widget · every screen", as: .systemMedium) {
    HerLiftWidget()
} timeline: {
    previewEntry(.ready)
    previewEntry(.logging, inbox: WidgetInbox(day: Calendar.current.startOfDay(for: Date()), reps: 8))
    previewEntry(.allSetsDone)
    previewEntry(.done)
    CoachEntry(date: Date(), snapshot: nil, inbox: WidgetInbox())
}

// MARK: - Preview data

/// Today's Chest · Core workout at 6:00 PM in the given phase, with two sets of the chest press to go.
private func previewEntry(_ phase: CoachSnapshot.Phase, inbox: WidgetInbox = WidgetInbox()) -> CoachEntry {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
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
        startedAt: phase == .ready ? nil : Date().addingTimeInterval(-32 * 60),
        summary: phase == .done ? CoachSnapshot.Summary(setCount: 5, minutes: 43) : nil, updatedAt: Date())
    return CoachEntry(date: Date(), snapshot: snapshot, inbox: inbox)
}
