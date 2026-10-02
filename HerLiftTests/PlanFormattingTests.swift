import Foundation
import Testing
@testable import HerLift

@MainActor
struct PlanFormattingTests {
    @Test func theTargetShowsSetsRepsAndAsksHerToFindTheWeight() {
        // Leg Press: 10–12 reps.
        #expect(PlanFormatting.target(of: planned("leg-press", sets: 4)) == "4 × 10–12 · find your weight")
        // Goblet Squat: 8–12 reps.
        #expect(PlanFormatting.target(of: planned("goblet-squat", sets: 3)) == "3 × 8–12 · find your weight")
    }

    @Test func theHeaderSaysTodayOrNamesTheWeekday() {
        // Leg Press 5 sets is 20 minutes, Glute Bridge 3 sets is 10 minutes.
        let workout = PlannedWorkout(
            weekday: 3, categoryIDs: ["legs", "glutes"],
            exercises: [planned("leg-press", sets: 5), planned("glute-bridge", sets: 3)])

        #expect(workout.estimatedMinutes == 30)
        #expect(PlanFormatting.workoutHeader(of: workout, isToday: true) == "Today · 2 exercises · 30 min")
        #expect(PlanFormatting.workoutHeader(of: workout, isToday: false) == "Wednesday · 2 exercises · 30 min")
    }

    private func planned(_ id: String, sets: Int) -> WorkoutExercise {
        let exercise = try! JSONExerciseRepository().exercises.first { $0.id == id }!
        return WorkoutExercise(exercise: exercise, sets: sets)
    }
}
