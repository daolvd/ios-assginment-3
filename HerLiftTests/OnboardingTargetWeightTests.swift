import Foundation
import Testing
@testable import HerLift

@MainActor
struct OnboardingTargetWeightTests {
    @Test func aTargetBelowAHealthyWeightIsRefusedWithTheLowestSafeWeight() {
        let viewModel = loseFatViewModel(target: "45")

        #expect(viewModel.targetWeightMessage
            == "This target is below a healthy weight for your height. Choose 51 kg or more.")
        #expect(!viewModel.canFinish)
    }

    @Test func aTargetNotBelowTheCurrentWeightIsRefused() {
        for target in ["62", "70"] {
            let viewModel = loseFatViewModel(target: target)
            #expect(viewModel.targetWeightMessage == "Choose a target below your current weight.")
            #expect(!viewModel.canFinish)
        }
    }

    @Test func aSensibleTargetIsAccepted() {
        let viewModel = loseFatViewModel(target: "56")

        #expect(viewModel.targetWeightMessage == nil)
        #expect(viewModel.canFinish)
        #expect(viewModel.targetWeightKg == 56)
    }

    @Test func aTargetWithACommaIsRead() {
        #expect(loseFatViewModel(target: "56,5").targetWeightKg == 56.5)
    }

    @Test func nothingTypedYetShowsNoMessageButCannotFinish() {
        let viewModel = loseFatViewModel(target: "")
        #expect(viewModel.targetWeightMessage == nil)
        #expect(!viewModel.canFinish)
        #expect(viewModel.targetWeightKg == nil)
    }

    @Test func goalsWithoutATargetIgnoreTheField() {
        let viewModel = loseFatViewModel(target: "45")
        viewModel.input.selectedGoalID = "buildMuscle"

        #expect(viewModel.targetWeightMessage == nil)
        #expect(viewModel.canFinish)
        #expect(viewModel.targetWeightKg == nil)
    }

    private func loseFatViewModel(target: String) -> OnboardingViewModel {
        let viewModel = OnboardingViewModel(goals: onboardingPreviewGoals)
        viewModel.input.height = "165"
        viewModel.input.weight = "62"
        viewModel.input.selectedGoalID = "loseFat"
        viewModel.input.targetWeight = target
        return viewModel
    }
}
