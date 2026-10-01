//
//  YourGoalView.swift
//  HerLift
//
//  Created by Van Dao Le on 1/10/2026.
//

import SwiftUI

struct YourGoalView: View {
    let goals: [Goal]
    @Binding var selectedGoalID: Goal.ID?
    @Binding var targetWeight: String
    var focusedField: FocusState<OnboardingField?>.Binding
    var actionTitle = "Build my plan"
    var canBuildPlan = true
    var targetWeightError: String?
    var onBuildPlan: (() -> Void)?

    var body: some View {
        OnboardingPageContent {
            VStack(alignment: .leading, spacing: 20) {
                OnboardingStyle.subtitle("Choose one goal.")
                HLGoalPicker(goals: goals, selection: $selectedGoalID)
                if goals.first(where: { $0.id == selectedGoalID })?.requiresTargetWeight == true {
                    OnboardingNumberField("Target weight (for Lose fat)", text: $targetWeight,
                                prompt: "56", unit: "kg", focusedField: focusedField, field: .targetWeight)
                    if let targetWeightError { HLInlineError(message: targetWeightError) }
                }
            }
        }
        .navigationTitle("Your goal")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Text("2 of 2").font(.footnote).foregroundStyle(HerLiftTheme.secondaryText)
                    .accessibilityLabel("Step 2 of 2")
            }
                .sharedBackgroundVisibility(.hidden)
        }
        .safeAreaInset(edge: .bottom) {
            OnboardingStyle.primaryButton(actionTitle) {
                focusedField.wrappedValue = nil
                onBuildPlan?()
            }
            .disabled(selectedGoalID == nil || onBuildPlan == nil || !canBuildPlan)
            .padding(.horizontal, 20).padding(.bottom, 12)
            .background(HerLiftTheme.background)
        }
    }
}

#Preview("Your goal") {
    OnboardingView(goals: onboardingPreviewGoals, initialPage: .goal, selectedGoalID: "loseFat",
                   onBuildPlan: { /* Preview only; plan creation is supplied by the caller. */ })
}
