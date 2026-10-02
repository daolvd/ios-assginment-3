//
//  MinutesPickerView.swift
//  HerLift
//
//  Created by Van Dao Le on 1/10/2026.
//

import SwiftUI

struct MinutesPickerView: View {
    @Binding var selection: Int
    let onDone: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 12) {
            Text("Minutes per workout").font(.headline)
            OnboardingStyle.helper("20–120 minutes, in steps of 5")
            Picker("Minutes per workout", selection: $selection) {
                ForEach(Array(stride(from: 20, through: 120, by: 5)), id: \.self) { value in
                    Text("\(value) min").tag(value)
                }
            }
            .pickerStyle(.wheel)
            OnboardingStyle.primaryButton("Done", action: onDone)
        }
        .padding(20)
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(HerLiftTheme.background)
    }
}

#Preview("Minutes picker") {
    @Previewable @State var selection = 120
    MinutesPickerView(selection: $selection, onDone: { /* Preview only. */ })
        .tint(HerLiftTheme.primary)
}
