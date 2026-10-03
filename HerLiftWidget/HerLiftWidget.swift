import AppIntents
import WidgetKit
import SwiftUI

struct CoachEntry: TimelineEntry {
    let date: Date
    let snapshot: CoachSnapshot?
    let inbox: WidgetInbox
}

struct CoachProvider: TimelineProvider {
    func placeholder(in context: Context) -> CoachEntry { galleryEntry() }

    /// The widget gallery shows today's workout with Start workout; anywhere else it shows the real state.
    func getSnapshot(in context: Context, completion: @escaping (CoachEntry) -> Void) {
        completion(context.isPreview ? galleryEntry() : entry(at: Date()))
    }

    /// The widget changes when the app publishes and when she taps a button; on its own it only changes when a
    /// rest ends and at midnight, when the day's workout no longer applies.
    func getTimeline(in context: Context, completion: @escaping (Timeline<CoachEntry>) -> Void) {
        let now = Date()
        let midnight = Calendar.current.startOfDay(for: now.addingTimeInterval(24 * 60 * 60))
        var entries = [entry(at: now)]
        if let snapshot = entries[0].snapshot, let restEndsAt = WidgetCoaching.restEnd(snapshot, entries[0].inbox),
           restEndsAt > now, restEndsAt < midnight {
            entries.append(entry(at: restEndsAt))
        }
        entries.append(entry(at: midnight))
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func entry(at date: Date) -> CoachEntry {
        CoachEntry(date: date, snapshot: CoachFiles.readSnapshot(), inbox: CoachFiles.readInbox())
    }

    /// A sample day for the gallery and the placeholder: a Chest · Core workout at 6:00 PM that has not started,
    /// the next workout on Legs, and this week with Monday, Wednesday and today as training days.
    private func galleryEntry() -> CoachEntry {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        func at(_ days: Int) -> Date {
            let day = calendar.date(byAdding: .day, value: days, to: today)!
            return calendar.date(byAdding: .minute, value: 18 * 60, to: day)!
        }
        let todayIndex = (calendar.component(.weekday, from: today) + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -todayIndex, to: today)!
        let week = (0..<7).map { offset -> CoachSnapshot.Day in
            let date = calendar.date(byAdding: .day, value: offset, to: monday)!
            let isTraining = [0, 2, todayIndex].contains(offset)
            return CoachSnapshot.Day(date: date, isTraining: isTraining, isDone: isTraining && date < today)
        }
        let step = CoachSnapshot.Step(
            exerciseID: "machine-chest-press", exerciseName: "Machine Chest Press", exerciseNumber: 1,
            exerciseCount: 2, setNumber: 1, setCount: 3, weightKg: 20, isBodyweight: false, minimumReps: 10,
            maximumReps: 12, restSeconds: 90)
        let snapshot = CoachSnapshot(
            phase: .ready, day: today,
            today: CoachSnapshot.Workout(title: "Chest · Core", minutes: 40, startsAt: at(0)),
            next: CoachSnapshot.Workout(title: "Legs", minutes: 45, startsAt: at(4)),
            week: week, steps: [step], loggedSetCount: 0, startedAt: nil, restEndsAt: nil, summary: nil,
            updatedAt: now)
        return CoachEntry(date: now, snapshot: snapshot, inbox: WidgetInbox(day: today))
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
        case .log(let step, let weightKg):
            LogSetWidgetView(step: step, weightKg: weightKg)
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
    previewEntry(.logging, inbox: WidgetInbox(day: Calendar.current.startOfDay(for: Date())))
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
        startedAt: phase == .ready ? nil : Date().addingTimeInterval(-32 * 60), restEndsAt: nil,
        summary: phase == .done ? CoachSnapshot.Summary(setCount: 5, minutes: 43) : nil, updatedAt: Date())
    return CoachEntry(date: Date(), snapshot: snapshot, inbox: inbox)
}
