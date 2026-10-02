import Foundation
import Observation

/// Her saved answers, editable on their own until she rebuilds the plan from them.
/// The answers are edited through the same view model the onboarding questions use.
@MainActor
@Observable
final class ProfileViewModel {
    let editor: OnboardingViewModel
    /// Why the plan could not be rebuilt from the changed answers.
    private(set) var planningError: PlanningError?
    @ObservationIgnored private let loadProfile: LoadOnboardingProfileUseCase
    @ObservationIgnored private let editPlan: EditWorkoutPlanUseCase
    /// The answers as last saved; anything different is an unsaved change.
    private var baseline: OnboardingInput

    init(editor: OnboardingViewModel, loadProfile: LoadOnboardingProfileUseCase, editPlan: EditWorkoutPlanUseCase) {
        self.editor = editor
        self.loadProfile = loadProfile
        self.editPlan = editPlan
        baseline = editor.input
    }

    /// Reads the saved answers and the goal of the stored plan. Changes she has not applied are kept.
    func refresh() {
        guard !hasUnsavedChanges else { return }
        editor.load(using: loadProfile)
        if let plan = try? editPlan.currentPlan() {
            editor.input.selectedGoalID = plan.goalID
            editor.input.targetWeight = plan.weightForecast.map { Self.text($0.targetKg) } ?? ""
        }
        baseline = editor.input
    }

    var hasUnsavedChanges: Bool { editor.input != baseline }
    var canRebuild: Bool { hasUnsavedChanges && editor.canFinish }

    /// Saves the answers and builds a new plan from them. Returns true when a new plan is waiting for her
    /// decision; on false the stored plan is untouched and `planningError` or `editor.error` says why.
    func rebuild(using generatePlan: GeneratePlanViewModel) -> Bool {
        planningError = nil
        guard editor.save(), let profile = editor.savedProfile, let goalID = editor.input.selectedGoalID else {
            return false
        }
        generatePlan.generate(profile: profile, goalID: goalID, targetWeightKg: editor.targetWeightKg)
        if case .failed(let error) = generatePlan.state {
            planningError = error
            return false
        }
        baseline = editor.input
        return true
    }

    // MARK: Summaries shown on the Profile screen

    var aboutSummary: String {
        let input = editor.input
        return [input.age, "\(Self.text(input.height)) cm", "\(Self.text(input.weight)) kg", input.experience.rawValue]
            .joined(separator: " · ")
    }

    var trainingSummary: String {
        let names = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        let days = editor.input.trainingDays.sorted().compactMap { names.indices.contains($0 - 1) ? names[$0 - 1] : nil }
        return "\(days.joined(separator: ", ")) · \(editor.input.minutes) min"
    }

    var goalSummary: String {
        guard let goal = editor.selectedGoal else { return "Not chosen" }
        guard goal.requiresTargetWeight, !editor.input.targetWeight.isEmpty else { return goal.title }
        return "\(goal.title) · \(Self.text(editor.input.targetWeight)) kg"
    }

    /// "165.0" → "165", "56,5" → "56.5"; text that is not a number is returned as typed.
    private static func text(_ value: String) -> String {
        let normal = value.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard let number = Double(normal) else { return value }
        return text(number)
    }

    private static func text(_ number: Double) -> String {
        number.rounded() == number ? String(Int(number)) : String(number)
    }
}
