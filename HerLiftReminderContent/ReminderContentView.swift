import SwiftUI

/// The workout reminder's own view: how long until she trains, what she trains and for how long. The Start workout
/// button below it is the notification's own.
struct ReminderContentView: View {
    /// The workout the reminder carries; nil for a reminder with no workout behind it.
    let workout: ReminderContent?
    /// The reminder's plain text, shown when there is no workout.
    let fallbackText: String
    /// When the view is shown, so a workout that has already started says so instead of counting down.
    var now = Date()

    var body: some View {
        if let workout {
            VStack(alignment: .leading, spacing: 6) {
                if workout.startsAt > now {
                    Text("STARTS IN").font(.caption.weight(.semibold)).foregroundStyle(Palette.primary)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(timerInterval: now...workout.startsAt, countsDown: true, showsHours: false)
                            .font(.system(size: 44, weight: .bold)).monospacedDigit()
                            .foregroundStyle(Palette.text)
                        Text("min").font(.subheadline.weight(.medium)).foregroundStyle(Palette.secondaryText)
                    }
                } else {
                    Text("TIME TO TRAIN").font(.caption.weight(.semibold)).foregroundStyle(Palette.primary)
                }
                Text(workout.title).font(.title2.weight(.semibold)).foregroundStyle(Palette.text)
                Text("Today at \(workout.startsAt.formatted(date: .omitted, time: .shortened)) · \(workout.durationLine)")
                    .font(.subheadline.weight(.medium)).foregroundStyle(Palette.secondaryText)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        } else {
            Text(fallbackText).font(.body).foregroundStyle(Palette.text)
                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// The app's colours, read from the extension's own copy of the colour assets.
private enum Palette {
    static let primary = Color("AccentColor")
    static let text = Color("HLText")
    static let secondaryText = Color("HLTextSecondary")
}

// MARK: - Previews

#Preview("Workout reminder") {
    ReminderContentView(workout: previewWorkout(startsInMinutes: 30), fallbackText: "")
        .frame(width: 390)
        .background(Color("HLBackground"))
}

#Preview("Workout reminder · already time to train") {
    ReminderContentView(workout: previewWorkout(startsInMinutes: -5), fallbackText: "")
        .frame(width: 390)
        .background(Color("HLBackground"))
}

#Preview("Reminder without a workout") {
    ReminderContentView(workout: nil, fallbackText: "This is how your reminder will look.")
        .frame(width: 390)
        .background(Color("HLBackground"))
}

// MARK: - Preview data

/// A Chest · Core workout of 40 minutes that starts the given number of minutes from now.
private func previewWorkout(startsInMinutes minutes: Int) -> ReminderContent {
    ReminderContent(
        title: "Chest · Core", minutes: 40, startsAt: Date().addingTimeInterval(Double(minutes * 60)))
}
