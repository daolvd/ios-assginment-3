//
//  YourTrainingView.swift
//  HerLift
//
//  Created by Van Dao Le on 1/10/2026.
//

import SwiftUI

struct YourTrainingView: View {
    @Binding var trainingDays: Set<Int>
    @Binding var minutes: Int
    @Binding var healthNote: String
    @Binding var clearedByDoctor: Bool
    var focusedField: FocusState<OnboardingField?>.Binding
    @State private var customMinutes: Int?
    @State private var usesCustomMinutes = false
    @State private var showsMinutes = false
    @State private var pendingMinutes = 45
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        OnboardingPageContent {
            VStack(alignment: .leading, spacing: 20) {
                OnboardingStyle.subtitle("We plan around your week.")
                VStack(alignment: .leading, spacing: 8) {
                    OnboardingStyle.fieldLabel("Training days")
                    HLDayPicker(selection: $trainingDays)
                }
                VStack(alignment: .leading, spacing: 8) {
                    OnboardingStyle.fieldLabel("Minutes per workout")
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(spacing: 8) { minuteChips }
                    } else {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 8) { minuteChips }
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 64))], spacing: 8) { minuteChips }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    OnboardingStyle.fieldLabel("Health (optional)")
                    TextField("Health note", text: $healthNote,
                              prompt: Text("Tell us about any health problems, injuries or conditions. If you have none, leave this blank.")
                                .foregroundStyle(HerLiftTheme.secondaryText),
                              axis: .vertical)
                        .lineLimit(4...6)
                        .focused(focusedField, equals: .health)
                        .padding(14)
                        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
                        .background(HerLiftTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                        .accessibilityLabel("Health, optional")
                    OnboardingStyle.helper("If you write something here, we’ll ask whether a doctor has cleared you to exercise.")
                }
                if !healthNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Toggle("Has a doctor cleared you to exercise?", isOn: $clearedByDoctor)
                        .font(.subheadline)
                        .padding(16)
                        .background(HerLiftTheme.surface, in: RoundedRectangle(cornerRadius: 14))
                    OnboardingStyle.helper("If not, please check with your doctor before you start. Your plan will start gently.")
                }
            }
        }
        .onAppear {
            if ![30, 45, 60, 90].contains(minutes) {
                customMinutes = minutes
                usesCustomMinutes = true
            }
        }
        .sheet(isPresented: $showsMinutes) {
            MinutesPickerView(selection: $pendingMinutes) {
                minutes = pendingMinutes
                customMinutes = pendingMinutes
                usesCustomMinutes = true
                showsMinutes = false
            }
        }
    }

    @ViewBuilder private var minuteChips: some View {
        ForEach([30, 45, 60, 90], id: \.self) { value in
            HLChip(title: "\(value)", isSelected: !usesCustomMinutes && minutes == value,
                   horizontalPadding: 4) {
                minutes = value
                usesCustomMinutes = false
            }
        }
        HLChip(title: customMinutes.map { "\($0)" } ?? "Other", isSelected: usesCustomMinutes,
               horizontalPadding: 4) {
            focusedField.wrappedValue = nil
            pendingMinutes = customMinutes ?? minutes
            showsMinutes = true
        }
        .accessibilityLabel("Other minutes per workout")
        .accessibilityValue(customMinutes.map { "\($0) minutes" } ?? "Not selected")
        .accessibilityHint("Opens the minutes picker")
    }
}

#Preview("Your training") {
    OnboardingView(goals: onboardingPreviewGoals, initialPage: .training)
}

#Preview("Health note") {
    OnboardingView(goals: onboardingPreviewGoals, initialPage: .training,
                   healthNote: "Mild asthma. I use an inhaler before running.")
}

#Preview("Training · large text") {
    OnboardingView(goals: onboardingPreviewGoals, initialPage: .training)
        .environment(\.dynamicTypeSize, .accessibility3)
}
