//
//  HLDayRow.swift
//  HerLift
//
//  Created by Van Dao Le on 1/10/2026.
//

import SwiftUI

struct HLDayRow: View {
    enum State { case done, today, upcoming, rest }

    let weekday: String
    let day: String
    let title: String
    let meta: String
    let state: State
    let onStart: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .caption) private var dateWidth: CGFloat = 48

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                Text(weekday).font(.caption.weight(.medium))
                    .foregroundStyle(state == .today ? HerLiftTheme.primary : HerLiftTheme.secondaryText)
                Text(day).font(.headline)
                    .foregroundStyle(state == .today ? HerLiftTheme.primary : HerLiftTheme.text)
            }
            .frame(width: dateWidth)
            .padding(.vertical, 8)
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(state == .today ? HerLiftTheme.primary : HerLiftTheme.border,
                                  lineWidth: state == .today ? 2 : 1)
            }
            .accessibilityElement(children: .combine)

            if state == .rest {
                Text("Rest").font(.subheadline).foregroundStyle(HerLiftTheme.secondaryText)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, minHeight: 44, maxHeight: .infinity, alignment: .leading)
                    .overlay {
                        RoundedRectangle(cornerRadius: 14).strokeBorder(HerLiftTheme.border, lineWidth: 1)
                    }
            } else {
                card
            }
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline).foregroundStyle(HerLiftTheme.text)
                    Text(meta).font(.footnote.weight(.medium)).foregroundStyle(HerLiftTheme.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if state == .today {
                    if !dynamicTypeSize.isAccessibilitySize { startButton }
                } else {
                    Text("›").font(.title2.weight(.semibold)).foregroundStyle(HerLiftTheme.secondaryText)
                        .accessibilityHidden(true)
                }
            }
            if state == .today && dynamicTypeSize.isAccessibilitySize { startButton }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(state == .today ? HerLiftTheme.background : HerLiftTheme.surface,
                    in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            if state == .today {
                RoundedRectangle(cornerRadius: 14).strokeBorder(HerLiftTheme.primary, lineWidth: 2)
            }
        }
    }

    private var startButton: some View {
        Button(action: onStart) {
            Text("Start").font(.footnote.weight(.medium)).foregroundStyle(HerLiftTheme.onPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(minHeight: 44)
                .background(HerLiftTheme.primary, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Start \(title)")
    }
}

#Preview("DayRow · Four states") {
    VStack(spacing: 16) {
        HLDayRow(weekday: "WED", day: "30", title: "Upper Body", meta: "5 exercises · 45 min", state: .done, onStart: {})
        HLDayRow(weekday: "WED", day: "30", title: "Upper Body", meta: "5 exercises · 45 min", state: .today, onStart: {})
        HLDayRow(weekday: "WED", day: "30", title: "Upper Body", meta: "5 exercises · 45 min", state: .upcoming, onStart: {})
        HLDayRow(weekday: "WED", day: "30", title: "", meta: "", state: .rest, onStart: {})
    }
    .padding(20)
    .background(HerLiftTheme.background)
}
