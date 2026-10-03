import AppIntents
import SwiftUI
import UIKit
import WidgetKit

/// The app's colours, read from the widget's own copy of the colour assets.
enum WidgetTheme {
    static let primary = Color("AccentColor")
    static let primarySoft = Color("AccentColor").opacity(0.12)
    static let onPrimary = Color("HLOnPrimary")
    static let background = Color("HLBackground")
    static let surface = Color("HLSurface")
    static let text = Color("HLText")
    static let secondaryText = Color("HLTextSecondary")
    static let border = Color("HLBorder")
}

// MARK: - Schedule, with Start workout on a training day

/// Today's workout with Start workout, or the next one, above the week strip.
struct ScheduleWidgetView: View {
    let today: CoachSnapshot.Workout?
    let next: CoachSnapshot.Workout?
    let canStart: Bool
    let week: [CoachSnapshot.Day]
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(eyebrow).font(.caption.weight(.semibold))
                        .foregroundStyle(today != nil ? WidgetTheme.primary : WidgetTheme.secondaryText)
                    Text(heading).font(.title2.weight(.semibold)).foregroundStyle(WidgetTheme.text)
                        .lineLimit(1).minimumScaleFactor(0.8)
                    if let detail {
                        Text(detail).font(.footnote.weight(.medium)).foregroundStyle(WidgetTheme.secondaryText)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                if canStart {
                    Button(intent: StartWorkoutIntent()) {
                        Text("Start workout").font(.subheadline.weight(.semibold))
                            .foregroundStyle(WidgetTheme.onPrimary)
                            .padding(.horizontal, 14).frame(height: 36)
                            .background(WidgetTheme.primary, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer(minLength: 8)
            WeekStrip(days: week, now: now)
        }
    }

    private var shown: CoachSnapshot.Workout? { today ?? next }

    private var eyebrow: String {
        if today != nil { return "TODAY" }
        return next != nil ? "NEXT WORKOUT" : "HERLIFT"
    }

    /// "6:00 PM" today, "Wed · 6:00 PM" another day.
    private var heading: String {
        guard let shown else { return "No workout planned" }
        let time = shown.startsAt.formatted(date: .omitted, time: .shortened)
        if today != nil { return time }
        return "\(shown.startsAt.formatted(.dateTime.weekday(.abbreviated))) · \(time)"
    }

    private var detail: String? {
        shown.map { "\($0.title) · about \($0.minutes) min" }
    }
}

/// Monday to Sunday: a black dot on days she trained, a pink dot on days still to train, today outlined.
struct WeekStrip: View {
    let days: [CoachSnapshot.Day]
    let now: Date

    private static let letters = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        if days.count == 7, days.contains(where: { Calendar.current.isDate($0.date, inSameDayAs: now) }) {
            HStack(spacing: 0) {
                ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                    cell(day, letter: Self.letters[index])
                    if index < 6 { Spacer(minLength: 0) }
                }
            }
        }
    }

    private func cell(_ day: CoachSnapshot.Day, letter: String) -> some View {
        let isToday = Calendar.current.isDate(day.date, inSameDayAs: now)
        return VStack(spacing: 2) {
            Text(letter).font(.caption.weight(.medium))
                .foregroundStyle(isToday ? WidgetTheme.primary : WidgetTheme.secondaryText)
            Text("\(Calendar.current.component(.day, from: day.date))").font(.subheadline.weight(.semibold))
                .foregroundStyle(isToday ? WidgetTheme.primary : day.isTraining ? WidgetTheme.text : WidgetTheme.secondaryText)
            Circle().frame(width: 5, height: 5)
                .foregroundStyle(day.isDone ? WidgetTheme.text : day.isTraining ? WidgetTheme.primary : .clear)
        }
        .frame(width: 40).padding(.vertical, 6)
        .overlay {
            if isToday { RoundedRectangle(cornerRadius: 10).strokeBorder(WidgetTheme.primary, lineWidth: 2) }
        }
    }
}

// MARK: - Log a set

/// The set she is on, the live rep counter, +1, reset and Complete set. Nothing here is typed.
struct LogSetWidgetView: View {
    let step: CoachSnapshot.Step
    let weightKg: Double?
    let reps: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                ExerciseThumbnail(exerciseID: step.exerciseID, size: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Exercise \(step.exerciseNumber) of \(step.exerciseCount) · Set \(step.setNumber) of \(step.setCount)")
                        .font(.caption.weight(.medium)).foregroundStyle(WidgetTheme.secondaryText)
                    Text(step.exerciseName).font(.headline).foregroundStyle(WidgetTheme.text)
                        .lineLimit(1).minimumScaleFactor(0.8)
                    Text(target).font(.footnote.weight(.medium)).foregroundStyle(WidgetTheme.secondaryText)
                }
            }
            Spacer(minLength: 8)
            HStack(spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(reps)").font(.system(size: 34, weight: .bold)).monospacedDigit()
                        .foregroundStyle(WidgetTheme.text).contentTransition(.numericText())
                    Text("reps").font(.footnote.weight(.medium)).foregroundStyle(WidgetTheme.secondaryText)
                }
                .accessibilityElement(children: .combine)
                Spacer(minLength: 0)
                Button(intent: AddRepIntent()) {
                    Text("+1").font(.headline).foregroundStyle(WidgetTheme.primary)
                        .frame(width: 48, height: 48).background(WidgetTheme.primarySoft, in: Circle())
                }
                .buttonStyle(.plain).accessibilityLabel("Add a rep")
                Button(intent: ResetRepsIntent()) {
                    Image(systemName: "arrow.counterclockwise").font(.headline).foregroundStyle(WidgetTheme.text)
                        .frame(width: 48, height: 48)
                        .overlay { Circle().strokeBorder(WidgetTheme.border, lineWidth: 1.5) }
                }
                .buttonStyle(.plain).accessibilityLabel("Reset reps")
                completeButton
            }
        }
    }

    /// Complete set; until a weight is known for the exercise, a link to set it in the app instead.
    @ViewBuilder
    private var completeButton: some View {
        if weightKg == nil {
            Link(destination: WorkoutLink.today) { pill("Set weight") }
        } else {
            Button(intent: CompleteSetIntent()) { pill("Complete set") }
                .buttonStyle(.plain)
                .opacity(reps > 0 ? 1 : 0.4)
        }
    }

    private func pill(_ title: String) -> some View {
        Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(WidgetTheme.onPrimary)
            .lineLimit(1).minimumScaleFactor(0.8)
            .padding(.horizontal, 14).frame(height: 48)
            .background(WidgetTheme.primary, in: Capsule())
    }

    /// "Target 20 kg × 10–12", "Bodyweight × 10–12", or "Find your weight × 10–12" until a weight is known.
    private var target: String {
        let reps = "\(step.minimumReps)–\(step.maximumReps)"
        if step.isBodyweight { return "Bodyweight × \(reps)" }
        guard let weightKg else { return "Find your weight × \(reps)" }
        let text = weightKg.rounded() == weightKg ? "\(Int(weightKg))" : String(format: "%.1f", weightKg)
        return "Target \(text) kg × \(reps)"
    }
}

// MARK: - Rest

/// The rest counting down, the next set and Skip rest.
struct RestWidgetView: View {
    let until: Date
    let next: CoachSnapshot.Step
    let now: Date

    var body: some View {
        VStack(spacing: 2) {
            Text("Rest").font(.subheadline.weight(.semibold)).foregroundStyle(WidgetTheme.secondaryText)
            Text(timerInterval: now...max(now, until), countsDown: true)
                .font(.system(size: 44, weight: .bold)).monospacedDigit()
                .multilineTextAlignment(.center).foregroundStyle(WidgetTheme.text)
            Text("Next: \(next.exerciseName) · Set \(next.setNumber) of \(next.setCount)")
                .font(.footnote.weight(.medium)).foregroundStyle(WidgetTheme.secondaryText).lineLimit(1)
            Spacer(minLength: 4)
            Button(intent: SkipRestIntent()) {
                Text("Skip rest").font(.subheadline.weight(.semibold)).foregroundStyle(WidgetTheme.secondaryText)
                    .frame(height: 36).padding(.horizontal, 16)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - All sets done

/// Every set is logged; finishing, with next time's weights, happens in the app.
struct AllSetsDoneWidgetView: View {
    let title: String
    let setCount: Int
    let startedAt: Date?
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ALL SETS DONE").font(.caption.weight(.semibold)).foregroundStyle(WidgetTheme.primary)
                    Text(title).font(.title2.weight(.semibold)).foregroundStyle(WidgetTheme.text).lineLimit(1)
                    Text(detail).font(.footnote.weight(.medium)).foregroundStyle(WidgetTheme.secondaryText)
                }
                Spacer(minLength: 0)
                Image(systemName: "checkmark").font(.title2.weight(.bold)).foregroundStyle(WidgetTheme.primary)
                    .frame(width: 56, height: 56).background(WidgetTheme.primarySoft, in: Circle())
                    .accessibilityHidden(true)
            }
            Spacer(minLength: 8)
            Link(destination: WorkoutLink.today) {
                Text("Finish workout").font(.subheadline.weight(.semibold)).foregroundStyle(WidgetTheme.onPrimary)
                    .frame(maxWidth: .infinity).frame(height: 44)
                    .background(WidgetTheme.primary, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    /// "5 sets · 32 min"
    private var detail: String {
        let sets = setCount == 1 ? "1 set" : "\(setCount) sets"
        guard let startedAt else { return sets }
        return "\(sets) · \(max(1, Int(now.timeIntervalSince(startedAt) / 60))) min"
    }
}

// MARK: - Workout done

/// Today's workout is finished; the next training day underneath.
struct WorkoutDoneWidgetView: View {
    let title: String
    let summary: CoachSnapshot.Summary?
    let next: CoachSnapshot.Workout?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text("TODAY").font(.caption.weight(.semibold)).foregroundStyle(WidgetTheme.secondaryText)
                Text("Workout done").font(.title2.weight(.semibold)).foregroundStyle(WidgetTheme.text)
                Text(detail).font(.footnote.weight(.medium)).foregroundStyle(WidgetTheme.secondaryText).lineLimit(1)
            }
            Spacer(minLength: 8)
            if let next {
                HStack(spacing: 8) {
                    Text("Next").font(.footnote.weight(.medium)).foregroundStyle(WidgetTheme.secondaryText)
                    Text(nextLine(next)).font(.subheadline.weight(.semibold)).foregroundStyle(WidgetTheme.text)
                        .lineLimit(1).minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(WidgetTheme.surface, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// "Chest · Core · 43 min · 5 sets"
    private var detail: String {
        guard let summary else { return title }
        var parts = [title]
        if summary.minutes > 0 { parts.append("\(summary.minutes) min") }
        parts.append(summary.setCount == 1 ? "1 set" : "\(summary.setCount) sets")
        return parts.joined(separator: " · ")
    }

    /// "Wed · Legs · 6:00 PM"
    private func nextLine(_ workout: CoachSnapshot.Workout) -> String {
        let day = workout.startsAt.formatted(.dateTime.weekday(.abbreviated))
        return "\(day) · \(workout.title) · \(workout.startsAt.formatted(date: .omitted, time: .shortened))"
    }
}

// MARK: - No plan

struct NoPlanWidgetView: View {
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus").font(.largeTitle).foregroundStyle(WidgetTheme.primary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("HerLift").font(.title2.weight(.semibold)).foregroundStyle(WidgetTheme.text)
                Text("Build your plan in the app to see your week here.")
                    .font(.footnote.weight(.medium)).foregroundStyle(WidgetTheme.secondaryText)
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Exercise photo

/// The exercise's photo from the widget's copy of the thumbnails, or an icon when there is none.
struct ExerciseThumbnail: View {
    let exerciseID: String
    let size: CGFloat

    var body: some View {
        Group {
            if let path = Bundle.main.path(forResource: exerciseID, ofType: "jpg"),
               let image = UIImage(contentsOfFile: path) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    WidgetTheme.surface
                    Image(systemName: "figure.strengthtraining.traditional").font(.title2)
                        .foregroundStyle(WidgetTheme.secondaryText)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.2))
        .accessibilityHidden(true)
    }
}
