import Foundation

nonisolated enum MuscleGroup: String, Codable, Sendable {
    case quads, chest, hamstrings, back, glutes, shoulders, arms, calves, core

    static let majorGroups: [Self] = [.quads, .chest, .hamstrings, .back, .glutes, .shoulders]
    static let lowerBody: Set<Self> = [.quads, .hamstrings, .glutes, .calves]
    var isMajor: Bool { ![Self.arms, .calves, .core].contains(self) }
}

nonisolated enum MovementPattern: String, Codable, Sendable {
    case knee, hip, push, pull, accessory, core
    static let required: Set<Self> = [.knee, .hip, .push, .pull]
}

nonisolated enum PlanGoalKind: String, CaseIterable, Sendable {
    case loseFat, buildMuscle, buildStrength, increaseGymConfidence
}

nonisolated enum GuidedEquipment: String, Sendable {
    case machine, cable
}

nonisolated enum ExercisePosition: String, Sendable {
    case floor, kneeling, seated
    var isFloorBased: Bool { self == .floor || self == .kneeling }
}

@MainActor
extension PlanRuleEngine {
    struct Context {
        let request: PlanRequest
        let goal: PlanGoalKind
        let strategy: TrainingStrategy
        let volume: WeeklyVolumePolicy
        let entries: [Entry]
        let configuration: PlanRuleConfiguration
    }

    struct Entry {
        let exercise: Exercise
        let muscle: MuscleGroup
        let movement: MovementPattern
        let compound: Bool
        let secondary: Set<MuscleGroup>
        var machine: Bool { GuidedEquipment(rawValue: exercise.equipment) != nil }
        var major: Bool { muscle.isMajor }
    }

    struct DaySelection {
        let weekday: Int
        var entries: [Entry] = []
    }

    var majorMuscles: [MuscleGroup] { MuscleGroup.majorGroups }
    var requiredMovements: Set<MovementPattern> { MovementPattern.required }
}
