import SwiftUI

/// Empty layout for review. No profile, exercises, forecast or plan is loaded.
struct PlanReviewView: View {
    private let weekdays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Draft · 12-week plan").font(.subheadline).foregroundStyle(HerLiftTheme.secondaryText)
                    HLListRow(title: "Goal", accessory: .value("—"))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    week
                    forecast
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Coach").font(.headline)
                        HLListRow(title: "—").clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(20)
            }
            .background(HerLiftTheme.background)
            .foregroundStyle(HerLiftTheme.text)
            .navigationTitle("Your plan")
            .navigationBarTitleDisplayMode(.large)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    OnboardingStyle.primaryButton("Accept plan") {}.disabled(true)
                    Button("Start over") {}.frame(minHeight: 44).disabled(true)
                }
                .padding(.horizontal, 20).padding(.bottom, 12)
                .background(HerLiftTheme.background)
            }
        }
        .tint(HerLiftTheme.primary)
    }

    private var week: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your week").font(.headline)
            VStack(spacing: 0) {
                ForEach(weekdays, id: \.self) { weekday in
                    DisclosureGroup {
                        HLListRow(title: "Workout", subtitle: "— exercises · — min")
                        HLListRow(title: "Exercise", subtitle: "— sets × — reps · — seconds rest")
                    } label: {
                        HStack {
                            Text(weekday).font(.headline)
                            Spacer()
                            Text("—").foregroundStyle(HerLiftTheme.secondaryText)
                        }
                    }
                    .padding(16)
                    if weekday != weekdays.last { Divider() }
                }
            }
            .background(HerLiftTheme.surface, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private var forecast: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Goal forecast").font(.headline)
            HLListRow(title: "Estimate", accessory: .value("—"))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            Text("Dự đoán — giả định bạn tập đều theo kế hoạch và kiểm soát ăn uống. Kết quả thực tế có thể khác.")
                .font(.footnote).foregroundStyle(HerLiftTheme.secondaryText)
        }
    }
}

#Preview("Review · UI only") { PlanReviewView() }
