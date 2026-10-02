import Foundation

/// How long a fat-loss goal may take at a steady, safe pace. A forecast, never a promise.
nonisolated struct WeightLossForecast: Equatable, Sendable {
    let currentKg: Double
    let targetKg: Double
    /// Week counted from the plan's start, at the fastest safe pace.
    let earliestWeek: Int
    /// Week counted from the plan's start, at the slowest pace.
    let latestWeek: Int
}

/// A point in the plan's first twelve weeks. Weeks count from the day the plan starts.
nonisolated struct ForecastMilestone: Equatable, Identifiable, Sendable {
    let startWeek: Int
    let endWeek: Int
    let title: String

    var id: Int { startWeek }
}
