//
//  AboutYouView.swift
//  HerLift
//
//  Created by Van Dao Le on 1/10/2026.
//

import SwiftUI

struct AboutYouView: View {
    typealias Experience = ExperienceLevel

    @Binding var age: String
    @Binding var height: String
    @Binding var weight: String
    @Binding var experience: Experience
    var focusedField: FocusState<OnboardingField?>.Binding
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        OnboardingPageContent {
            VStack(alignment: .leading, spacing: 20) {
                OnboardingStyle.subtitle("Stays on your phone.")
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: 12) { bodyFields }
                } else {
                    HStack(alignment: .top, spacing: 10) { bodyFields }
                }
                VStack(alignment: .leading, spacing: 8) {
                    OnboardingStyle.fieldLabel("Experience")
                    HLChipPicker(selection: $experience, options: Experience.allCases) { $0.rawValue }
                }
            }
        }
    }

    @ViewBuilder private var bodyFields: some View {
        OnboardingNumberField("Age", text: $age, prompt: "29", focusedField: focusedField, field: .age, keyboard: .numberPad)
        OnboardingNumberField("Height", text: $height, prompt: "165", unit: "cm", focusedField: focusedField, field: .height)
        OnboardingNumberField("Weight", text: $weight, prompt: "62", unit: "kg", focusedField: focusedField, field: .weight)
    }
}

#Preview("About you") {
    @Previewable @State var age = "29"
    @Previewable @State var height = "165"
    @Previewable @State var weight = "68"
    @Previewable @State var experience = ExperienceLevel.beginner
    @Previewable @FocusState var focus: OnboardingField?
    AboutYouView(age: $age, height: $height, weight: $weight, experience: $experience, focusedField: $focus)
        .tint(HerLiftTheme.primary)
}
