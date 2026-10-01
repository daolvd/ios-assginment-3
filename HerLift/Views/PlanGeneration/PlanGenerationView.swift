import SwiftUI

/// Layout only. The phase is selected by the preview; no generation runs here.
struct PlanGenerationView: View {
    enum Phase { case building, failed }
    var phase: Phase = .building

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if phase == .building { checklist }
                    else {
                        HLInlineError(message: "We couldn't build your plan. Your answers are saved.")
                        OnboardingStyle.primaryButton("Try again") {}.disabled(true)
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
                    Button("Change my answers") {}.disabled(true)
                }
            }
        }
        .tint(HerLiftTheme.primary)
    }

    private var checklist: some View {
        VStack(alignment: .leading, spacing: 20) {
            ProgressView("Creating your week")
            VStack(spacing: 0) {
                ForEach(["Checking your answers", "Choosing your training approach", "Building your week",
                         "Checking your plan", "Saving your draft"], id: \.self) { title in
                    HLListRow(title: title, accessory: .value("—"))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
            HLListRow(title: "Planner", accessory: .value("—"))
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}

#Preview("Building · UI only") { PlanGenerationView() }
#Preview("Error · UI only") { PlanGenerationView(phase: .failed) }
