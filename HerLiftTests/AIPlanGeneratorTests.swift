import Foundation
import Testing
@testable import HerLift

@MainActor
struct AIPlanGeneratorTests {
    @Test func aiChoosesScheduleAndRulesSupplyTargetsWithoutPrivateAnswersInPrompt() async throws {
        let catalogue = try JSONExerciseRepository().exercises
        let request = request(cleared: true)
        let reference = try PlanRuleEngine().generate(request, catalogue: catalogue)
        let answer = AIWorkoutSchedule(days: reference.days.reversed().map { day in
            AIWorkoutDay(weekday: day.weekday, title: "AI selected session",
                         exerciseIDs: day.exercises.reversed().map(\.exerciseID))
        })
        let recorder = PromptRecorder()
        let generator = FoundationModelPlanGenerator(catalogue: catalogue) { prompt in
            recorder.prompts.append(prompt)
            return answer
        }

        let plan = try await generator.generate(request)

        #expect(generator.kind == .onDeviceAI)
        #expect(plan.generatorRaw == "onDeviceAI")
        #expect(plan.profile.healthNote == request.healthNote)
        #expect(plan.days.map(\.weekday) == answer.days.map(\.weekday))
        #expect(plan.days.map { $0.exercises.map(\.exerciseID) } == answer.days.map(\.exerciseIDs))
        #expect(plan.days.allSatisfy { $0.title == "AI selected session" && $0.estimatedMinutes > 0 })
        #expect(plan.days.flatMap(\.exercises).allSatisfy { $0.targetSets == 2 && $0.targetWeightKg == nil })
        try PlanRuleEngine().validate(plan, request: request, catalogue: catalogue)
        let prompt = try #require(recorder.prompts.first)
        let payload = try #require(JSONSerialization.jsonObject(with: Data(prompt.utf8)) as? [String: Any])
        #expect(!prompt.contains("PRIVATE_HEALTH_NOTE"))
        #expect(["age", "heightCm", "weightKg", "targetWeightKg", "healthNote", "clearedByDoctor"].allSatisfy { payload[$0] == nil })
        let exercises = try #require(payload["exercises"] as? [[String: Any]])
        let allowed = try PlanRuleEngine().eligibleExercises(for: request, catalogue: catalogue)
        #expect(Set(exercises.compactMap { $0["id"] as? String }) == Set(allowed.map(\.id)))
        #expect(recorder.prompts.count == 1)
    }

    @Test func invalidAIOutputAndModelFailuresAreRejectedAndScreeningRunsFirst() async throws {
        let catalogue = try JSONExerciseRepository().exercises
        let recorder = PromptRecorder()
        let generator = FoundationModelPlanGenerator(catalogue: catalogue) { prompt in
            recorder.prompts.append(prompt)
            return AIWorkoutSchedule(days: [1, 3, 6].map {
                AIWorkoutDay(weekday: $0, title: "Invalid", exerciseIDs: ["invented-exercise"])
            })
        }
        await #expect(throws: CreatePersonalisedPlanError.medicalClearanceRequired) {
            try await generator.generate(request(cleared: false))
        }
        #expect(recorder.prompts.isEmpty)
        await #expect(throws: CreatePersonalisedPlanError.invalidTrainingPlan) {
            try await generator.generate(request(cleared: true))
        }
        #expect(recorder.prompts.count == 1)
        let reference = try PlanRuleEngine().generate(request(cleared: true), catalogue: catalogue)
        let wrongDays = FoundationModelPlanGenerator(catalogue: catalogue) { _ in
            AIWorkoutSchedule(days: reference.days.map { day in
                AIWorkoutDay(weekday: day.weekday == 1 ? 2 : day.weekday, title: "Wrong day",
                             exerciseIDs: day.exercises.map(\.exerciseID))
            })
        }
        await #expect(throws: CreatePersonalisedPlanError.invalidTrainingPlan) {
            try await wrongDays.generate(request(cleared: true))
        }
        let failing = FoundationModelPlanGenerator(catalogue: catalogue) { _ in
            throw CocoaError(.featureUnsupported)
        }
        await #expect(throws: CreatePersonalisedPlanError.invalidTrainingPlan) {
            try await failing.generate(request(cleared: true))
        }
    }

    private final class PromptRecorder {
        var prompts: [String] = []
    }

    private func request(cleared: Bool) -> PlanRequest {
        PlanRequest(experience: .beginner, goalID: "buildStrength", targetWeightKg: nil,
                    trainingWeekdays: [1, 3, 6], sessionMinutes: 45, age: 55,
                    heightCm: 165, weightKg: 95, healthNote: "PRIVATE_HEALTH_NOTE", clearedByDoctor: cleared)
    }
}
