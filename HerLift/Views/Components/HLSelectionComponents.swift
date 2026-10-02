//
//  HLSelectionComponents.swift
//  HerLift
//
//  Created by Van Dao Le on 1/10/2026.
//

import SwiftUI

struct HLChip: View {
    let title: String
    let isSelected: Bool
    var horizontalPadding: CGFloat = 14
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(isSelected ? .headline : .body)
                .lineLimit(1).minimumScaleFactor(0.7)
                .foregroundStyle(isSelected ? HerLiftTheme.onPrimary : HerLiftTheme.text)
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(isSelected ? HerLiftTheme.primary : HerLiftTheme.surface,
                            in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.5)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct HLChipPicker<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [Value]
    let title: (Value) -> String
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 8) { chips }
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { chips }
                VStack(spacing: 8) { chips }
            }
        }
    }

    private var chips: some View {
        ForEach(options, id: \.self) { option in
            HLChip(title: title(option), isSelected: selection == option) { selection = option }
        }
    }
}

struct HLDayCheckbox: View {
    let day: String
    var fullDayName: String? = nil
    let isChecked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(isChecked ? HerLiftTheme.primary : HerLiftTheme.background)
                    .frame(width: 24, height: 24)
                    .overlay {
                        if isChecked {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.semibold))
                                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                                .foregroundStyle(HerLiftTheme.onPrimary)
                        } else {
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(HerLiftTheme.border, lineWidth: 1.5)
                        }
                    }
                Text(day).font(.subheadline).foregroundStyle(HerLiftTheme.text)
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(fullDayName ?? day)
        .accessibilityValue(isChecked ? "Selected" : "Not selected")
        .accessibilityAddTraits(isChecked ? .isSelected : [])
    }
}

struct HLDayPicker: View {
    @Binding var selection: Set<Int>
    var allowed: ClosedRange<Int> = 2...7
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if dynamicTypeSize.isAccessibilitySize {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 72))]) { dayButtons }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 0) { dayButtons }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))]) { dayButtons }
                }
            }
            Text("Pick \(allowed.lowerBound)–\(allowed.upperBound) days · \(selection.count) selected")
                .font(.footnote).foregroundStyle(HerLiftTheme.secondaryText)
        }
    }

    private var dayButtons: some View {
        ForEach(dayNames.indices, id: \.self) { index in
            let weekday = index + 1
            let selected = selection.contains(weekday)
            HLDayCheckbox(day: String(dayNames[index].prefix(3)), fullDayName: dayNames[index], isChecked: selected) {
                if selected { selection.remove(weekday) }
                else if selection.count < allowed.upperBound { selection.insert(weekday) }
            }
            .disabled(!selected && selection.count >= allowed.upperBound)
        }
    }
}

#Preview("Chips & weekdays") {
    @Previewable @State var minutes = 45
    @Previewable @State var days: Set<Int> = [1, 3, 5]
    VStack(spacing: 20) {
        HLChipPicker(selection: $minutes, options: [30, 45, 60, 90]) { "\($0)" }
        HLDayPicker(selection: $days)
    }
    .padding(20).background(HerLiftTheme.background)
}
