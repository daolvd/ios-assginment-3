//
//  HLContentComponents.swift
//  HerLift
//
//  Created by Van Dao Le on 1/10/2026.
//

import SwiftUI

struct HLListRow: View {
    enum Accessory { case chevron, value(String), none }

    let title: String
    var subtitle: String? = nil
    var accessory: Accessory = .none

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline).foregroundStyle(HerLiftTheme.text)
                if let subtitle {
                    Text(subtitle).font(.footnote.weight(.medium)).foregroundStyle(HerLiftTheme.secondaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            switch accessory {
            case .chevron:
                Text("›").font(.title2.weight(.semibold)).foregroundStyle(HerLiftTheme.secondaryText)
                    .accessibilityHidden(true)
            case .value(let value):
                Text(value).font(.footnote.weight(.medium)).foregroundStyle(HerLiftTheme.secondaryText)
            case .none:
                EmptyView()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(minHeight: 44)
        .background(HerLiftTheme.surface)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct HLInlineError: View {
    let message: String
    var recovery: String? = nil

    init(message: String, recovery: String? = nil) {
        self.message = message
        self.recovery = recovery
    }

    init(_ error: some LocalizedError) {
        message = error.errorDescription ?? error.localizedDescription
        recovery = error.recoverySuggestion
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("!").font(.caption.weight(.medium)).foregroundStyle(HerLiftTheme.background)
                .frame(width: 18, height: 18)
                .background(HerLiftTheme.text, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(message).font(.headline).foregroundStyle(HerLiftTheme.text)
                if let recovery {
                    Text(recovery).font(.footnote.weight(.medium)).foregroundStyle(HerLiftTheme.secondaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(HerLiftTheme.surface, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}

struct HLIllustrationCard: View {
    var imageName: String? = nil
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                if let imageName {
                    Image(imageName).resizable().scaledToFit().padding(16)
                } else {
                    Text("Exercise illustration (vector asset)")
                        .font(.footnote.weight(.medium)).foregroundStyle(HerLiftTheme.secondaryText)
                        .padding(16)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 176)
            .background(HerLiftTheme.surface, in: RoundedRectangle(cornerRadius: 14))
            .accessibilityHidden(true)
            Text(caption).font(.subheadline).foregroundStyle(HerLiftTheme.text)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(caption)
    }
}

#Preview("List, error & illustration") {
    VStack(spacing: 16) {
        HLListRow(title: "Title", subtitle: "Subtitle", accessory: .chevron)
        HLListRow(title: "Title", subtitle: "Subtitle", accessory: .value("Value"))
        HLListRow(title: "Title", subtitle: "Subtitle")
        HLInlineError(message: "What went wrong", recovery: "What to do next")
        HLIllustrationCard(caption: "Cue line")
    }
    .padding(20).background(HerLiftTheme.background)
}
