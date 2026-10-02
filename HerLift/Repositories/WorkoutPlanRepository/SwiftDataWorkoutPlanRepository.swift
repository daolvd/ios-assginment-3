import Foundation
import SwiftData

@MainActor
final class SwiftDataWorkoutPlanRepository: WorkoutPlanRepository {
    private let modelContext: ModelContext
    private let exercises: any ExerciseRepository

    init(modelContext: ModelContext, exercises: any ExerciseRepository) {
        self.modelContext = modelContext
        self.exercises = exercises
    }

    func loadPlan() throws -> WorkoutPlan? {
        let descriptor = FetchDescriptor<TrainingPlan>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        guard let stored = try modelContext.fetch(descriptor).first else { return nil }

        let workouts = try stored.days.sorted { $0.sortIndex < $1.sortIndex }.map { day in
            let planned = try day.exercises.sorted { $0.sortIndex < $1.sortIndex }.map { item in
                // A plan that points at an exercise no longer in the catalogue cannot be shown honestly.
                guard let exercise = exercises.exercise(id: item.exerciseID) else {
                    throw CocoaError(.coderValueNotFound)
                }
                return WorkoutExercise(exercise: exercise, sets: item.sets)
            }
            return PlannedWorkout(weekday: day.weekday, categoryIDs: day.categoryIDs, exercises: planned)
        }
        return WorkoutPlan(goalID: stored.goalID, workouts: workouts)
    }

    func savePlan(_ plan: WorkoutPlan) throws {
        do {
            try deleteStoredPlans()
            let stored = TrainingPlan(goalID: plan.goalID)
            modelContext.insert(stored)
            for (dayIndex, workout) in plan.workouts.enumerated() {
                let day = WorkoutDay(sortIndex: dayIndex, weekday: workout.weekday, categoryIDs: workout.categoryIDs)
                day.plan = stored
                for (index, item) in workout.exercises.enumerated() {
                    let planned = PlannedExercise(sortIndex: index, exerciseID: item.exercise.id, sets: item.sets)
                    planned.day = day
                }
            }
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    func deletePlan() throws {
        do {
            try deleteStoredPlans()
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    private func deleteStoredPlans() throws {
        for stored in try modelContext.fetch(FetchDescriptor<TrainingPlan>()) {
            modelContext.delete(stored)
        }
    }
}
