import Foundation
import Observation

@MainActor
@Observable
final class OnboardingViewModel {
    enum PlanGenerationPhase: Equatable {
        case editing, building, ready, failed
    }

    let goals: [Goal]
    var input: OnboardingInput
    private(set) var savedProfile: OnboardingProfile?
    var error: OnboardingProfileError?
    @ObservationIgnored private let saveProfile: SaveOnboardingProfileUseCase?

    private(set) var generationPhase: PlanGenerationPhase = .editing
    private(set) var plan: TrainingPlan?
    private(set) var plannerLabel: String?
    private(set) var generationError: CreatePersonalisedPlanError?
    @ObservationIgnored private let createPlan: CreatePersonalisedPlanUseCase?

    /// Omit the use cases only for view previews; saving and generating require
    /// dependencies supplied by the app.
    init(goals: [Goal], input: OnboardingInput = OnboardingInput(),
         saveProfile: SaveOnboardingProfileUseCase? = nil,
         createPlan: CreatePersonalisedPlanUseCase? = nil) {
        self.goals = goals
        self.input = input
        self.saveProfile = saveProfile
        self.createPlan = createPlan
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
        guard let goal = selectedGoal, generationPhase != .building else { return false }
        if goal.requiresTargetWeight {
            guard let target = parsedTargetWeight, let height = parsedHeightCm else { return false }
            return PlanRules.isSafeTargetWeight(target, heightCm: height)
        }
        return true
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

    /// Screens K → L: save the answers, then let UC1 validate and draft the week.
    /// Saving first is what lets the failure screen say "Your answers are saved."
    func buildPlan() async {
        guard let createPlan, canBuildPlan else { return }
        if savedProfile == nil {
            guard save() else { return }
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
        generationError = nil
        generationPhase = .building
        do {
            plan = try await createPlan.execute(request)
            plannerLabel = createPlan.plannerLabel
            generationPhase = .ready
        } catch {
            generationError = error
            // Answer-level problems send her back to fix the form; the rest are
            // full-screen failures (R).
            generationPhase = switch error {
            case .missingGoal, .medicalClearanceRequired, .unsafeTargetWeight: .editing
            default: .failed
            }
        }
    }

    /// The R screen's "Try again": same answers, same generator, bounded to one call.
    func retryBuildPlan() async {
        guard generationPhase == .failed else { return }
        await buildPlan()
    }

    /// "Change my answers" and "Start over": the plan is discarded, the answers stay.
    func changeAnswers() {
        generationPhase = .editing
        plan = nil
        plannerLabel = nil
        generationError = nil
    }

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
