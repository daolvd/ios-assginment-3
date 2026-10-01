import Foundation
import Observation

@MainActor
@Observable
final class OnboardingViewModel {
    enum PlanGenerationPhase: Equatable {
        case editing, building, ready, failed
    }

    let goals: [Goal]
    let exercises: [Exercise]
    var input: OnboardingInput
    private(set) var savedProfile: OnboardingProfile?
    var error: OnboardingProfileError?
    @ObservationIgnored private let saveProfile: SaveOnboardingProfileUseCase?

    private(set) var generationPhase: PlanGenerationPhase = .editing
    private(set) var plan: TrainingPlan?
    private(set) var plannerLabel: String?
    private(set) var generationError: CreatePersonalisedPlanError?
    @ObservationIgnored private let createPlan: CreatePersonalisedPlanUseCase?
    @ObservationIgnored private let acceptTrainingPlan: AcceptTrainingPlanUseCase?
    private(set) var acceptanceError: AcceptTrainingPlanError?
    @ObservationIgnored private var generationID: UUID?

    /// Omit the use cases only for view previews; saving and generating require
    /// dependencies supplied by the app.
    init(goals: [Goal], exercises: [Exercise] = [], input: OnboardingInput = OnboardingInput(),
         saveProfile: SaveOnboardingProfileUseCase? = nil,
         createPlan: CreatePersonalisedPlanUseCase? = nil,
         acceptPlan: AcceptTrainingPlanUseCase? = nil) {
        self.goals = goals
        self.exercises = exercises
        self.input = input
        self.saveProfile = saveProfile
        self.createPlan = createPlan
        self.acceptTrainingPlan = acceptPlan
    }

    var canSave: Bool { saveProfile != nil }

    var selectedGoal: Goal? {
        goals.first { $0.id == input.selectedGoalID }
    }

    /// The Q-screen inline error; only an entered-but-unsafe target reports here.
    var targetWeightError: CreatePersonalisedPlanError? {
        guard selectedGoal?.requiresTargetWeight == true,
              let target = parsedTargetWeight,
              let height = parsedHeightCm,
              !PlanRules.isSafeTargetWeight(target, heightCm: height) else { return nil }
        return .unsafeTargetWeight
    }

    var canBuildPlan: Bool {
        guard createPlan != nil, let goal = selectedGoal, generationPhase != .building else { return false }
        if goal.requiresTargetWeight {
            guard let target = parsedTargetWeight, let height = parsedHeightCm,
                  let currentWeight = parsedPositiveNumber(input.weight), target < currentWeight else { return false }
            return PlanRules.isSafeTargetWeight(target, heightCm: height)
        }
        return true
    }

    var targetWeightMessage: String? {
        if let targetWeightError { return targetWeightError.errorDescription }
        guard selectedGoal?.requiresTargetWeight == true, let target = parsedTargetWeight,
              let currentWeight = parsedPositiveNumber(input.weight), target >= currentWeight else { return nil }
        return "Choose a target below your current weight."
    }

    func load(using useCase: LoadOnboardingProfileUseCase) {
        do {
            guard let profile = try useCase.execute() else { return }
            input.age = String(profile.age)
            input.height = String(profile.heightCm)
            input.weight = String(profile.weightKg)
            input.experience = profile.experience
            input.trainingDays = Set(profile.trainingWeekdays)
            input.minutes = profile.sessionMinutes
            input.healthNote = profile.healthNote ?? ""
            input.clearedByDoctor = profile.clearedByDoctor
            savedProfile = profile
            error = nil
        } catch {
            self.error = error
        }
    }

    @discardableResult
    func save() -> Bool {
        guard let saveProfile else {
            error = .couldNotSaveProfile
            return false
        }
        do {
            savedProfile = try saveProfile.execute(input)
            error = nil
            return true
        } catch {
            self.error = error
            return false
        }
    }

    /// EN: Save current edited answers before generation, so retries never use an outdated profile.
    /// VI: Lưu câu trả lời vừa sửa trước khi tạo lịch, tránh retry dùng profile cũ.
    func buildPlan() async {
        guard !Task.isCancelled, let createPlan, canBuildPlan else { return }
        generationError = nil
        guard save() else {
            generationPhase = .editing
            return
        }
        guard let profile = savedProfile else { return }
        let request = PlanRequest(
            experience: profile.experience,
            goalID: input.selectedGoalID ?? "",
            targetWeightKg: selectedGoal?.requiresTargetWeight == true ? parsedTargetWeight : nil,
            trainingWeekdays: profile.trainingWeekdays,
            sessionMinutes: profile.sessionMinutes,
            age: profile.age,
            heightCm: profile.heightCm,
            weightKg: profile.weightKg,
            healthNote: profile.healthNote,
            clearedByDoctor: profile.clearedByDoctor
        )
        let attemptID = UUID()
        generationID = attemptID
        plan = nil
        plannerLabel = createPlan.plannerLabel
        generationError = nil
        generationPhase = .building
        do {
            let generated = try await createPlan.execute(request)
            guard generationID == attemptID, !Task.isCancelled else { return }
            plan = generated
            plannerLabel = PlanGeneratorKind(rawValue: generated.generatorRaw)?.label
            generationPhase = .ready
        } catch {
            guard generationID == attemptID, !Task.isCancelled else { return }
            generationError = error
            // Answer-level problems send her back to fix the form; the rest are
            // full-screen failures (R).
            generationPhase = switch error {
            case .missingGoal, .medicalClearanceRequired, .unsafeTargetWeight: .editing
            default: .failed
            }
        }
    }

    /// EN: Retry a failed build; the use case owns the bounded AI retry and fallback.
    /// VI: Tạo lại khi lỗi; use case quản lý giới hạn retry AI và fallback.
    func retryBuildPlan() async {
        guard generationPhase == .failed else { return }
        await buildPlan()
    }

    /// EN: Discard the unaccepted plan and ignore any late result from a cancelled build.
    /// VI: Bỏ plan chưa chấp nhận và bỏ qua kết quả đến muộn của lần tạo đã hủy.
    func changeAnswers() {
        guard plan?.statusRaw != "active" else { return }
        generationID = nil
        if let plan {
            do { try createPlan?.discard(plan) }
            catch {
                generationError = error
                generationPhase = .failed
                return
            }
        }
        generationPhase = .editing
        plan = nil
        plannerLabel = nil
        generationError = nil
        acceptanceError = nil
    }

    var canAcceptPlan: Bool {
        acceptTrainingPlan != nil && generationPhase == .ready && plan?.statusRaw == "draft"
    }

    /// EN: Update the screen only after acceptance is saved; leave the draft available for retry on error.
    /// VI: Chỉ cập nhật màn hình sau khi lưu Accept thành công; giữ draft để thử lại khi lỗi.
    func acceptPlan() {
        guard canAcceptPlan, let plan, let acceptTrainingPlan else { return }
        do {
            self.plan = try acceptTrainingPlan.execute(planID: plan.id)
            acceptanceError = nil
        } catch {
            acceptanceError = error
        }
    }

    func dismissAcceptanceError() { acceptanceError = nil }

    func loadSavedPlan() {
        guard let createPlan else { return }
        do {
            guard let stored = try createPlan.loadSavedPlan() else { return }
            plan = stored
            input.selectedGoalID = stored.goalRaw
            input.targetWeight = stored.targetWeightKg.map { String($0) } ?? ""
            plannerLabel = PlanGeneratorKind(rawValue: stored.generatorRaw)?.label
            generationPhase = .ready
        } catch {
            generationError = error
            generationPhase = .failed
        }
    }

    var planMilestones: [String] {
        guard let plan else { return [] }
        return createPlan?.milestones(for: plan.goalRaw) ?? []
    }

    func dismissGenerationError() { generationError = nil }

    private var parsedHeightCm: Double? {
        parsedPositiveNumber(input.height)
    }

    private var parsedTargetWeight: Double? {
        parsedPositiveNumber(input.targetWeight)
    }

    private func parsedPositiveNumber(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(trimmed.replacingOccurrences(of: ",", with: ".")), value.isFinite, value > 0 else {
            return nil
        }
        return value
    }
}
