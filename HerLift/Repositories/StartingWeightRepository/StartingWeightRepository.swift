import Foundation

/// The starting weights a new plan begins with.
@MainActor
protocol StartingWeightRepository {
    var table: StartingWeightTable { get }
}
