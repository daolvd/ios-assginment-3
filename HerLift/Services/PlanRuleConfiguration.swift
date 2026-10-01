import Foundation

nonisolated struct PlanRuleConfiguration: Decodable, Sendable {
    struct ExerciseRole: Decodable, Sendable {
        let muscle: MuscleGroup
        let movement: MovementPattern
        let compound: Bool
    }

    struct CoachMessages: Decodable, Sendable {
        let standard: String
        let conservative: String
    }

    let version: Int
    let exerciseRoles: [String: ExerciseRole]
    let muscleAliases: [String: MuscleGroup]
    let coachMessages: CoachMessages
    let milestones: [String: [String]]

    static let bundled: PlanRuleConfiguration? = try? load()

    static func load(bundle: Bundle = .main) throws -> PlanRuleConfiguration {
        guard let url = bundle.url(forResource: "plan-rules", withExtension: "json")
            ?? bundle.url(forResource: "plan-rules", withExtension: "json", subdirectory: "Resources")
        else { throw CocoaError(.fileNoSuchFile) }
        let configuration = try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
        guard configuration.version == 1, !configuration.exerciseRoles.isEmpty,
              !configuration.muscleAliases.isEmpty,
              !configuration.coachMessages.standard.isEmpty,
              !configuration.coachMessages.conservative.isEmpty,
              PlanGoalKind.allCases.allSatisfy({ configuration.milestones[$0.rawValue] != nil })
        else { throw CocoaError(.fileReadCorruptFile) }
        return configuration
    }
}
