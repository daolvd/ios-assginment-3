import SwiftUI

struct PlanGenerationView: View {
    enum Phase { case building, failed }
    var phase: Phase = .building
    var plannerLabel: String?
    var error: CreatePersonalisedPlanError?
    var onRetry: (() -> Void)?
    var onChangeAnswers: (() -> Void)?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if phase == .building { checklist }
                    else {
                        HLInlineError(message: error?.errorDescription ?? "We couldn't build your plan. Your answers are saved.")
                        if let suggestion = error?.recoverySuggestion {
                            Text(suggestion).foregroundStyle(HerLiftTheme.secondaryText)
                        }
                        OnboardingStyle.primaryButton("Try again") { onRetry?() }.disabled(onRetry == nil)
                    }
                }
                .padding(20)
            }
            .background(HerLiftTheme.background)
            .foregroundStyle(HerLiftTheme.text)
            .navigationTitle("Building your plan")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Change my answers") { onChangeAnswers?() }.disabled(onChangeAnswers == nil)
                }
            }
        }
        .tint(HerLiftTheme.primary)
    }

    private var checklist: some View {
        VStack(alignment: .leading, spacing: 20) {
            ProgressView("Creating your week")
            Text("Choosing your exercises and checking your weekly schedule.")
                .foregroundStyle(HerLiftTheme.secondaryText)
            HLListRow(title: "Planner", accessory: .value(plannerLabel ?? "—"))
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}

#Preview("Building") { PlanGenerationView() }
#Preview("Error") { PlanGenerationView(phase: .failed) }
