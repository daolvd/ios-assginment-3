import Foundation

nonisolated struct Category: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
}

nonisolated struct Tag: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let kind: String

    private enum CodingKeys: String, CodingKey {
        case id, title
        case kind = "type"
    }
}

nonisolated enum TrainingLevel: String, Codable, Sendable {
    case beginner
    case intermediate
}

nonisolated struct TrainingPattern: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let level: TrainingLevel
    let description: String
    let sessionGroups: [TrainingPatternSession]
}

nonisolated struct TrainingPatternSession: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let categoryIDs: [Category.ID]
}

nonisolated struct PlannerConfig: Codable, Sendable {
    let supportedDaysPerWeek: PlannerIntRange
    let supportedSessionMinutes: [Int]
    let maxPrimaryCategoriesPerSession: Int
    let allowCoreAsAdditionalCategory: Bool
    let selection: PlannerSelectionConfig
}

nonisolated struct PlannerIntRange: Codable, Equatable, Sendable {
    let min: Int
    let max: Int
}

nonisolated struct PlannerSelectionConfig: Codable, Equatable, Sendable {
    let usePatternAsCycle: Bool
    let doNotCreateFullBodySessions: Bool
    let onlyUseKnownExerciseIDs: Bool
}
