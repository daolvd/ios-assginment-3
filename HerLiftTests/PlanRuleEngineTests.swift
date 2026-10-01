import Foundation
import Testing
@testable import HerLift

@MainActor
struct PlanRuleEngineTests {
    @Test func generatedWeeksRespectSelectedDaysAndCombinedLimits() throws {
        let catalogue = try JSONExerciseRepository().exercises
        let engine = PlanRuleEngine()
        for (days, restricted) in [([7, 1], false), ([1, 3, 6], false), (Array(1...7), false), (Array(1...7), true)] {
            let request = request(days: days, restricted: restricted)
            let plan = try engine.generate(request, catalogue: catalogue)
            try engine.validate(plan, request: request, catalogue: catalogue)
            #expect(plan.statusRaw == "draft")
            #expect(plan.generatorRaw == "ruleBased")
            #expect(plan.profile.trainingWeekdays == days.sorted())
            #expect(plan.days.count == min(days.count, 6))
            #expect(plan.days.allSatisfy { $0.estimatedMinutes <= 30 })
            #expect(plan.days.flatMap(\.exercises).allSatisfy { $0.targetWeightKg == nil })
            if days.count == 7 {
                #expect(plan.days.flatMap(\.exercises).reduce(0) { $0 + $1.targetSets } <= 24)
            }
            if restricted {
                #expect(plan.strategyRaw == "conservative+lowImpact+olderBeginner")
                for target in plan.days.flatMap(\.exercises) {
                    let exercise = try #require(catalogue.first { $0.id == target.exerciseID })
                    #expect(["machine", "cable"].contains(exercise.equipment))
                    #expect(!["floor", "kneeling"].contains(exercise.position))
                    #expect(target.targetSets == 2)
                    #expect(target.restSeconds == exercise.defaultRestSeconds + 30)
                }
            }
            let repeated = try engine.generate(request, catalogue: catalogue)
            #expect(repeated.days.map(\.weekday) == plan.days.map(\.weekday))
            #expect(repeated.days.map { $0.exercises.map(\.exerciseID) } == plan.days.map { $0.exercises.map(\.exerciseID) })
        }
    }

    @Test func screeningAndValidationRejectUnsafeInputsAndModifiedTargets() throws {
        let catalogue = try JSONExerciseRepository().exercises
        let engine = PlanRuleEngine()
        let blocked = request(days: [1, 3], restricted: true, cleared: false)
        #expect(throws: CreatePersonalisedPlanError.medicalClearanceRequired) {
            try engine.generate(blocked, catalogue: catalogue)
        }
        #expect(throws: CreatePersonalisedPlanError.noSuitableExercises) {
            try engine.generate(request(days: [1, 3]), catalogue: [])
        }
        let input = request(days: [1, 3, 6])
        let plan = try engine.generate(input, catalogue: catalogue)
        let target = try #require(plan.days.first?.exercises.first)
        target.targetWeightKg = 50
        #expect(throws: CreatePersonalisedPlanError.planDraftInvalid) { try engine.validate(plan, request: input, catalogue: catalogue) }
        target.targetWeightKg = nil
        plan.days[0].estimatedMinutes = 1
        #expect(throws: CreatePersonalisedPlanError.planDraftInvalid) { try engine.validate(plan, request: input, catalogue: catalogue) }
        plan.generatorRaw = "onDeviceAI"
        try engine.applyRules(to: plan, request: input, catalogue: catalogue)
        #expect(plan.generatorRaw == "onDeviceAI")
        try engine.validate(plan, request: input, catalogue: catalogue)
        target.exerciseID = "unknown"
        #expect(throws: CreatePersonalisedPlanError.planDraftInvalid) { try engine.validate(plan, request: input, catalogue: catalogue) }
        let boundary = PlanRequest(experience: .beginner, goalID: "loseFat", targetWeightKg: 47.36,
                                   trainingWeekdays: [1, 3, 6], sessionMinutes: 30, age: 29,
                                   heightCm: 160, weightKg: 76.8, healthNote: nil, clearedByDoctor: false)
        let forecast = try engine.generate(boundary, catalogue: catalogue)
        #expect(forecast.strategyRaw == "lowImpact")
        #expect(try #require(forecast.forecastMaxWeeks) > 12)
    }

    private func request(days: [Int], restricted: Bool = false, cleared: Bool = true) -> PlanRequest {
        PlanRequest(experience: .beginner, goalID: "buildStrength", targetWeightKg: nil,
                    trainingWeekdays: days, sessionMinutes: 30, age: restricted ? 55 : 29,
                    heightCm: 165, weightKg: restricted ? 95 : 62,
                    healthNote: restricted ? "Asthma" : nil, clearedByDoctor: restricted && cleared)
    }
}
