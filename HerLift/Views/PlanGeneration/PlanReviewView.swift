import SwiftUI

struct PlanReviewView: View {
    var plan: TrainingPlan?
    var goalTitle: String?
    var exercises: [Exercise] = []
    var milestones: [String] = []
    var onStartOver: (() -> Void)?
    var canAccept = false
    var acceptanceError: AcceptTrainingPlanError?
    var onAccept: (() -> Void)?
    var onDismissError: (() -> Void)?
    private let weekdays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    private var isActive: Bool { plan?.statusRaw == "active" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("\(plan?.targetWeeks ?? 12)-week plan · \(isActive ? "Active" : "Ready for review")")
                        .font(.subheadline).foregroundStyle(HerLiftTheme.secondaryText)
                    HLListRow(title: "Goal", accessory: .value(goalTitle ?? "—"))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    HLListRow(title: "Planner", accessory: .value(plan.flatMap {
                        PlanGeneratorKind(rawValue: $0.generatorRaw)?.label
                    } ?? "—"))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    if plan?.profile.trainingWeekdays.count == 7 {
                        Text("6 training days + 1 day off each week.")
                            .font(.subheadline).foregroundStyle(HerLiftTheme.secondaryText)
                    }
                    week
                    forecast
                    VStack(alignment: .leading, spacing: 8) {
                        Text(plan?.generatorRaw == PlanGeneratorKind.onDeviceAI.rawValue ? "Coach" : "HerLift guidance").font(.headline)
                        HLListRow(title: plan?.coachText ?? "—").clipShape(RoundedRectangle(cornerRadius: 14))
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
                    if isActive {
                        Label("Plan accepted", systemImage: "checkmark.circle.fill")
                            .font(.headline).foregroundStyle(HerLiftTheme.primary).frame(minHeight: 44)
                    } else {
                        OnboardingStyle.primaryButton("Accept plan") { onAccept?() }
                            .disabled(!canAccept || onAccept == nil)
                        Button("Start over") { onStartOver?() }.frame(minHeight: 44).disabled(onStartOver == nil)
                    }
                }
                .padding(.horizontal, 20).padding(.bottom, 12)
                .background(HerLiftTheme.background)
            }
        }
        .tint(HerLiftTheme.primary)
        .alert("Couldn't accept plan", isPresented: Binding(
            get: { acceptanceError != nil },
            set: { if !$0 { onDismissError?() } }
        )) {
            Button("OK") { onDismissError?() }
        } message: {
            Text(acceptanceError?.localizedDescription ?? "")
        }
    }

    private var week: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your week").font(.headline)
            VStack(spacing: 0) {
                ForEach(weekdays.indices, id: \.self) { index in
                    if let day = plan?.days.first(where: { $0.weekday == index + 1 }) {
                        DisclosureGroup {
                            HLListRow(title: day.title,
                                      subtitle: "\(day.exercises.count) exercises · ~\(day.estimatedMinutes) min")
                            ForEach(day.exercises.sorted { $0.sortIndex < $1.sortIndex }, id: \.id) { target in
                                HLListRow(title: exercises.first { $0.id == target.exerciseID }?.name ?? target.exerciseID,
                                          subtitle: "\(target.targetSets) sets × \(target.minimumReps)–\(target.maximumReps) reps · \(target.restSeconds) seconds rest")
                            }
                        } label: {
                            HStack {
                                Text(weekdays[index]).font(.headline)
                                Spacer()
                                Text("~\(day.estimatedMinutes) min").foregroundStyle(HerLiftTheme.secondaryText)
                            }
                        }
                        .padding(16)
                    } else {
                        HLListRow(title: weekdays[index], subtitle: plan == nil ? "—" : "Day off")
                    }
                    if index != weekdays.indices.last { Divider() }
                }
            }
            .background(HerLiftTheme.surface, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private var forecast: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Goal forecast").font(.headline)
            if let minimum = plan?.forecastMinWeeks, let maximum = plan?.forecastMaxWeeks {
                HLListRow(title: "Estimate", accessory: .value("Around week \(minimum)–\(maximum)"))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            } else if !milestones.isEmpty {
                VStack(spacing: 0) {
                    ForEach(milestones, id: \.self) { HLListRow(title: $0) }
                }
                .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                HLListRow(title: "Estimate", accessory: .value("—"))
            }
            Text("Dự đoán — giả định bạn tập đều theo kế hoạch và kiểm soát ăn uống. Kết quả thực tế có thể khác.")
                .font(.footnote).foregroundStyle(HerLiftTheme.secondaryText)
        }
    }
}

#Preview("Review") { PlanReviewView() }
