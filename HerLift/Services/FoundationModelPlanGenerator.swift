import Foundation
import FoundationModels

/// EN: A temporary model response: days and ordered IDs only. It is not a saved plan model.
/// VI: Kết quả tạm từ model: chỉ ngày và ID theo thứ tự. Đây không phải model plan để lưu.
@Generable
nonisolated struct AIWorkoutSchedule {
    @Guide(description: "Training days for one week", .count(2...6))
    var days: [AIWorkoutDay]
}

@Generable
nonisolated struct AIWorkoutDay {
    @Guide(description: "Monday is 1; Sunday is 7", .range(1...7))
    var weekday: Int
    @Guide(description: "Short English session name, such as Upper body")
    var title: String
    @Guide(description: "Exact allowed exercise IDs in performance order", .count(1...16))
    var exerciseIDs: [String]
}

@MainActor
final class FoundationModelPlanGenerator: PlanGenerating {
    nonisolated let kind = PlanGeneratorKind.onDeviceAI
    typealias ProposeSchedule = @MainActor @Sendable (String) async throws -> AIWorkoutSchedule

    private let catalogue: [Exercise]
    private let proposeSchedule: ProposeSchedule

    /// EN: Production uses the on-device model. The alternate closure lets tests supply a fixed response.
    /// VI: Khi chạy thật dùng model trên thiết bị. Closure thay thế giúp test cung cấp kết quả cố định.
    init(catalogue: [Exercise], proposeSchedule: @escaping ProposeSchedule = FoundationModelPlanGenerator.proposeOnDevice) {
        self.catalogue = catalogue
        self.proposeSchedule = proposeSchedule
    }

    /// EN: Screen first → ask AI once → build TrainingPlan → let rules fill numbers and check the schedule.
    /// VI: Kiểm tra trước → gọi AI một lần → tạo TrainingPlan → để rule điền số và kiểm tra lịch.
    nonisolated func generate(_ request: PlanRequest) async throws(CreatePersonalisedPlanError) -> TrainingPlan {
        try await generateOnMainActor(request)
    }

    private func generateOnMainActor(_ request: PlanRequest) async throws(CreatePersonalisedPlanError) -> TrainingPlan {
        let engine = PlanRuleEngine()
        let context = try engine.prepare(request, catalogue: catalogue)
        do {
            try Task.checkCancellation()
            let prompt = try AIPlanPrompt(context: context).encoded()
            let schedule = try await proposeSchedule(prompt)
            try Task.checkCancellation()
            let plan = try makePlan(schedule, context: context)
            try engine.applyRules(to: plan, request: request, catalogue: catalogue)
            return plan
        } catch let error as CreatePersonalisedPlanError {
            throw error
        } catch {
            // EN: Model availability, generation and cancellation failures use the existing service error.
            // VI: Model chưa sẵn sàng, lỗi sinh lịch hoặc hủy tác vụ dùng lỗi service hiện có.
            throw .invalidTrainingPlan
        }
    }

    private static func proposeOnDevice(_ prompt: String) async throws -> AIWorkoutSchedule {
        guard case .available = SystemLanguageModel.default.availability else {
            throw CreatePersonalisedPlanError.invalidTrainingPlan
        }
        // EN: A new session per call avoids sharing another user's planning conversation.
        // VI: Mỗi lần gọi tạo session mới để không trộn nội dung xếp lịch của lần trước.
        let session = LanguageModelSession(instructions: AIPlanPrompt.instructions)
        let response = try await session.respond(to: prompt, generating: AIWorkoutSchedule.self,
                                                options: GenerationOptions(temperature: 0.2, maximumResponseTokens: 1500))
        return response.content
    }

    /// EN: Copy the AI's choices into existing models. Rules replace zero placeholders before returning.
    /// VI: Chép lựa chọn AI vào model hiện có. Rule thay các số tạm bằng 0 trước khi trả kết quả.
    private func makePlan(_ schedule: AIWorkoutSchedule, context: PlanRuleEngine.Context) throws(CreatePersonalisedPlanError) -> TrainingPlan {
        guard (2...6).contains(schedule.days.count), schedule.days.allSatisfy({ day in
            !day.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && day.title.count <= 80
                && (1...16).contains(day.exerciseIDs.count)
        }) else { throw .invalidTrainingPlan }
        let request = context.request
        let profile = UserProfile(age: request.age, heightCm: request.heightCm, weightKg: request.weightKg,
                                  experienceRaw: request.experience.rawValue, trainingWeekdays: request.trainingWeekdays.sorted(),
                                  sessionMinutes: request.sessionMinutes, healthNote: request.healthNote,
                                  clearedByDoctor: request.clearedByDoctor)
        let plan = TrainingPlan(profile: profile, goalRaw: request.goalID, strategyRaw: context.strategy.rawValue,
                                generatorRaw: kind.rawValue, coachText: "")
        plan.days = schedule.days.enumerated().map { index, choice in
            let day = WorkoutDay(plan: plan, sortIndex: index, weekday: choice.weekday,
                                 title: choice.title.trimmingCharacters(in: .whitespacesAndNewlines), estimatedMinutes: 0)
            day.exercises = choice.exerciseIDs.enumerated().map { index, id in
                PlannedExercise(workoutDay: day, sortIndex: index, exerciseID: id,
                                targetSets: 0, minimumReps: 0, maximumReps: 0, restSeconds: 0)
            }
            return day
        }
        return plan
    }
}
