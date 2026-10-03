//
//  HLGoalPicker.swift
//  HerLift
//
//  Created by Van Dao Le on 1/10/2026.
//

import SwiftUI

struct HLGoalPicker: View {
    let goals: [Goal]
    @Binding var selection: Goal.ID?

    var body: some View {
        VStack(spacing: 0) {
            ForEach(goals) { goal in
                Button {
                    selection = goal.id
                } label: {
                    HStack {
                        Text(goal.title).font(.headline).foregroundStyle(HerLiftTheme.text)
                        Spacer()
                        if selection == goal.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(HerLiftTheme.primary)
                                .accessibilityHidden(true)
                        }
                    }
                    .padding()
                    .frame(minHeight: 54)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == goal.id ? .isSelected : [])
                if goal.id != goals.last?.id { HerLiftTheme.border.frame(height: 1) }
            }
        }
        .background(HerLiftTheme.surface, in: RoundedRectangle(cornerRadius: 14))
    }
}

#Preview("Goal picker") {
    @Previewable @State var selection: Goal.ID? = "loseFat"
    HLGoalPicker(goals: (try? JSONGoalRepository().goals) ?? [], selection: $selection)
        .padding(20).background(HerLiftTheme.background)
}
