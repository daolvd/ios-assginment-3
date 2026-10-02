import Foundation

nonisolated extension TrainingLevel: Comparable {
    private var rank: Int {
        switch self {
        case .beginner: 0
        case .intermediate: 1
        }
    }

    static func < (lhs: TrainingLevel, rhs: TrainingLevel) -> Bool { lhs.rank < rhs.rank }
}

/// Everything the planner needs to know about the person. Nothing here is derived from free text.
nonisolated struct UserPlanningProfile: Equatable, Sendable {
    let level: TrainingLevel
    let goalID: Goal.ID
    /// Monday = 1 … Sunday = 7. Between 2 and 7 distinct days.
    let trainingDays: [Int]
    let sessionMinutes: Int
    /// Only allow exercises tagged low impact.
    var requiresLowImpact = false
    /// Leave out exercises that start or end on the floor.
    var mustAvoidFloorExercises = false
    /// She wrote something in the health box. The text itself never reaches the planner.
    var reportsHealthConcern = false
    var clearedByDoctor = false
}

nonisolated extension UserPlanningProfile {
    /// Builds the planner input from saved onboarding answers. The onboarding answers contain no
    /// structured movement limits, so both hard constraints stay off. Only whether a health note
    /// exists is passed on, never its text.
    init(profile: OnboardingProfile, goalID: Goal.ID) {
        self.init(
            level: profile.experience == .beginner ? .beginner : .intermediate,
            goalID: goalID,
            trainingDays: profile.trainingWeekdays,
            sessionMinutes: profile.sessionMinutes,
            reportsHealthConcern: !(profile.healthNote?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true),
            clearedByDoctor: profile.clearedByDoctor
        )
    }
}
