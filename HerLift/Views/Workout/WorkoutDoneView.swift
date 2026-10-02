import SwiftUI

/// The end of a workout: what she did, the starting weights it showed, and the changes it proposes for next time.
struct WorkoutDoneView: View {
    let viewModel: WorkoutSessionViewModel
    let summary: WorkoutSummary
    let onBack: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Workout done").font(.largeTitle.bold()).foregroundStyle(HerLiftTheme.text)
                        .accessibilityAddTraits(.isHeader)
                    Text(subtitle).font(.subheadline).foregroundStyle(HerLiftTheme.secondaryText)
                }

                if !summary.proposals.isEmpty { proposals }

                ForEach(summary.startingWeights) { starting in
                    Text("Starting weight saved: \(starting.exerciseName) \(NextSetSuggestion.text(starting.weightKg)) kg")
                        .font(.subheadline).foregroundStyle(HerLiftTheme.text)
                }
                if summary.proposals.isEmpty, summary.startingWeights.isEmpty {
                    Text("Nice work. Your plan stays as it is.")
                        .font(.subheadline).foregroundStyle(HerLiftTheme.secondaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 24)
        }
        .safeAreaInset(edge: .bottom) {
            Button("Back to My Plan", action: onBack)
                .font(.headline).foregroundStyle(HerLiftTheme.primary)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(HerLiftTheme.background)
        }
    }

    private var subtitle: String {
        var parts = [summary.title]
        if let minutes = summary.minutes { parts.append("\(minutes) min") }
        parts.append(summary.setCount == 1 ? "1 set" : "\(summary.setCount) sets")
        return parts.joined(separator: " · ")
    }

    private var proposals: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Next time · \(summary.proposals.count) \(summary.proposals.count == 1 ? "change" : "changes")")
                .font(.headline).foregroundStyle(HerLiftTheme.text)
                .accessibilityAddTraits(.isHeader)

            HLGroup {
                ForEach(summary.proposals) { proposal in
                    HLProposalRow(
                        exercise: proposal.exerciseName, change: proposal.changeText,
                        state: state(of: proposal),
                        onApply: { viewModel.apply(proposal) }, onKeep: { viewModel.keep(proposal) })
                }
            }

            if !viewModel.pendingProposals.isEmpty {
                HStack(spacing: 12) {
                    OnboardingStyle.primaryButton("Apply all") { viewModel.applyAll() }
                    Button { viewModel.keepAll() } label: {
                        Text("Keep all").font(.headline).foregroundStyle(HerLiftTheme.text)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(HerLiftTheme.surface, in: RoundedRectangle(cornerRadius: 14))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            Text("Your plan only changes for the ones you apply.")
                .font(.footnote).foregroundStyle(HerLiftTheme.secondaryText)
                .frame(maxWidth: .infinity)
        }
    }

    private func state(of proposal: WeightProposal) -> HLProposalRow.State {
        switch viewModel.decisions[proposal.id] {
        case .applied: .applied
        case .kept: .kept
        case nil: .pending
        }
    }
}
