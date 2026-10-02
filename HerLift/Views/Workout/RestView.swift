import SwiftUI

/// The pause between sets: a countdown, what comes next, and a weight suggestion she can take or leave.
/// It leaves by itself when the time is up.
struct RestView: View {
    let viewModel: WorkoutSessionViewModel
    let rest: WorkoutSessionViewModel.RestState

    @ScaledMetric(relativeTo: .largeTitle) private var countdownSize: CGFloat = 96

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Rest").font(.headline).foregroundStyle(HerLiftTheme.secondaryText)
                Text(timerInterval: Date.now...max(rest.endsAt, Date.now), countsDown: true)
                    .font(.system(size: countdownSize, weight: .bold)).monospacedDigit()
                    .foregroundStyle(HerLiftTheme.text)
                    .minimumScaleFactor(0.5).lineLimit(1)
                if let next = viewModel.restNextLine {
                    Text(next).font(.subheadline).foregroundStyle(HerLiftTheme.secondaryText)
                }
            }
            .padding(.top, 48)
            .accessibilityElement(children: .combine)

            if let suggestion = rest.suggestion { buddyCard(suggestion) }
            Spacer()
            Button("Skip rest") { viewModel.endRest() }
                .font(.subheadline).foregroundStyle(HerLiftTheme.secondaryText)
                .frame(minHeight: 44)
        }
        .padding(.horizontal, 20).padding(.bottom, 16)
        .frame(maxWidth: .infinity)
        // When the time is up, go back to logging the next set.
        .task(id: rest.endsAt) {
            let remaining = rest.endsAt.timeIntervalSinceNow
            if remaining > 0 { try? await Task.sleep(for: .seconds(remaining)) }
            if !Task.isCancelled { viewModel.endRest() }
        }
    }

    private func buddyCard(_ suggestion: NextSetSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(suggestion.message).font(.body).foregroundStyle(HerLiftTheme.text)
            HStack(spacing: 12) {
                Button(suggestion.useTitle) { viewModel.useSuggestion() }
                    .buttonStyle(.borderedProminent).buttonBorderShape(.roundedRectangle(radius: 12))
                    .controlSize(.large)
                Button(suggestion.keepTitle) { viewModel.keepWeight() }
                    .font(.headline).foregroundStyle(HerLiftTheme.text)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HerLiftTheme.surface, in: RoundedRectangle(cornerRadius: 14))
    }
}
