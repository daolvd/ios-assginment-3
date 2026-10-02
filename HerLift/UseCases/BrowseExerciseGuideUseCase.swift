import Foundation

nonisolated struct ExerciseGuideSection: Identifiable, Sendable {
    let id: String
    let title: String
    let exercises: [Exercise]
}

nonisolated enum ExerciseGuideError: LocalizedError, Equatable {
    case exerciseNotFound

    var errorDescription: String? {
        switch self {
        case .exerciseNotFound: "We couldn't find that exercise."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .exerciseNotFound: "Go back to the Exercise Guide and choose another one."
        }
    }
}

/// Read-only queries over the bundled exercise catalogue for the Exercise Guide.
@MainActor
struct BrowseExerciseGuideUseCase {
    let repository: any ExerciseRepository

    /// Exercises grouped by muscle group, in catalogue order. A blank query returns everything;
    /// otherwise an exercise matches when its name, muscles or equipment contain the query.
    func sections(matching query: String = "") -> [ExerciseGuideSection] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let found = repository.exercises.filter { trimmed.isEmpty || matches($0, trimmed) }

        var order: [String] = []
        var grouped: [String: [Exercise]] = [:]
        for exercise in found {
            if grouped[exercise.categoryID] == nil { order.append(exercise.categoryID) }
            grouped[exercise.categoryID, default: []].append(exercise)
        }
        return order.compactMap { id in
            guard let exercises = grouped[id], let first = exercises.first else { return nil }
            return ExerciseGuideSection(id: id, title: first.muscleGroup, exercises: exercises)
        }
    }

    func exercise(id: Exercise.ID) throws(ExerciseGuideError) -> Exercise {
        guard let exercise = repository.exercise(id: id) else { throw .exerciseNotFound }
        return exercise
    }

    func videoURL(for exercise: Exercise) -> URL? {
        repository.videoURL(for: exercise)
    }

    private func matches(_ exercise: Exercise, _ query: String) -> Bool {
        let fields = [exercise.name, exercise.muscleGroup, exercise.primaryMuscle, exercise.equipment]
            + exercise.secondaryMuscles
        return fields.contains { $0.localizedStandardContains(query) }
    }
}
