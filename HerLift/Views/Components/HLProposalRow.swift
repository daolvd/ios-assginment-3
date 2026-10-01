//
//  HLProposalRow.swift
//  HerLift
//
//  Created by Van Dao Le on 1/10/2026.
//

import SwiftUI

struct HLProposalRow: View {
    enum State { case pending, applied, kept }

    let exercise: String
    let change: String
    let state: State
    let onApply: () -> Void
    let onKeep: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    heading
                    Spacer(minLength: 8)
                    changeLabel
                }
                VStack(alignment: .leading, spacing: 4) { heading; changeLabel }
            }
            switch state {
            case .pending:
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: 10) { actions }
                } else {
                    HStack(spacing: 10) { actions }
                }
            case .applied:
                Text("✓ Applied - your plan is updated")
                    .font(.footnote.weight(.medium)).foregroundStyle(HerLiftTheme.text)
            case .kept:
                Text("Kept - no change")
                    .font(.footnote.weight(.medium)).foregroundStyle(HerLiftTheme.secondaryText)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(HerLiftTheme.surface)
    }

    private var heading: some View {
        Text(exercise).font(.headline).foregroundStyle(HerLiftTheme.text)
    }

    private var changeLabel: some View {
        Text(change).font(.headline)
            .foregroundStyle(state == .kept ? HerLiftTheme.secondaryText : HerLiftTheme.primary)
    }

    @ViewBuilder private var actions: some View {
        Button(action: onApply) { Text("Apply").frame(maxWidth: .infinity, minHeight: 32) }
            .buttonStyle(.bordered).tint(HerLiftTheme.primary)
            .accessibilityLabel("Apply change for \(exercise)")
        Button(action: onKeep) { Text("Keep").frame(maxWidth: .infinity, minHeight: 32) }
            .buttonStyle(.bordered).tint(HerLiftTheme.text)
            .accessibilityLabel("Keep current plan for \(exercise)")
    }
}

#Preview("Proposals") {
    @Previewable @State var state = HLProposalRow.State.pending
    VStack(spacing: 16) {
        HLProposalRow(exercise: "Lat Pulldown", change: "30 → 32.5 kg", state: state,
                      onApply: { state = .applied }, onKeep: { state = .kept })
        HLProposalRow(exercise: "Lat Pulldown", change: "30 → 32.5 kg", state: .applied, onApply: {}, onKeep: {})
        HLProposalRow(exercise: "Lat Pulldown", change: "30 → 32.5 kg", state: .kept, onApply: {}, onKeep: {})
    }
    .padding(20).background(HerLiftTheme.background)
}
