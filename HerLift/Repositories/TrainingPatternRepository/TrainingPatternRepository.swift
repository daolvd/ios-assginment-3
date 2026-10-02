import Foundation

@MainActor
protocol TrainingPatternRepository {
    var patterns: [TrainingPattern] { get }
    func load() throws -> [TrainingPattern]
}
