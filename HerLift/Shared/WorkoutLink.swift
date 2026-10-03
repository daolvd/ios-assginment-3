import Foundation

/// The link a widget or notification uses to open the app on today's workout.
nonisolated enum WorkoutLink {
    static let today = URL(string: "herlift://workout/today")!
}
