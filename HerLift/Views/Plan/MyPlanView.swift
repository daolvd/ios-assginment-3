import SwiftUI

/// Home: the week's seven days, with today's workout ready to start and the goal at the bottom.
/// The caller supplies the NavigationStack; the Guide is a tab of its own.
struct MyPlanView: View {
    @Bindable var viewModel: MyPlanViewModel

    var body: some View {
        Group {
            if let plan = viewModel.plan, let week = viewModel.week {
                content(plan: plan, week: week)
            } else {
                Color.clear
            }
        }
        .background(HerLiftTheme.background)
        .navigationTitle("My Plan")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(isPresented: Binding(
            get: { viewModel.openedWeekday != nil }, set: { if !$0 { viewModel.openedWeekday = nil } }
        )) {
            if let day = viewModel.week?.days.first(where: { $0.weekday == viewModel.openedWeekday }), let workout = day.workout {
                WorkoutDayView(
                    workout: workout,
                    session: Calendar.current.isDateInToday(day.date) ? viewModel.sessionViewModel(for: workout) : nil,
                    opensLog: viewModel.opensLog,
                    onFinished: {
                        viewModel.openedWeekday = nil
                        viewModel.load()
                    })
            }
        }
        .onAppear { viewModel.load() }
    }

    private func content(plan: WorkoutPlan, week: PlanWeek) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Week \(week.weekNumber) of \(PlanWeek.totalWeeks) · \(week.doneCount) of \(week.workoutCount) done")
                    .font(.subheadline).foregroundStyle(HerLiftTheme.secondaryText)
                    .padding(.bottom, 4)
                ForEach(week.days) { day in row(for: day) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 24)
        }
        .safeAreaInset(edge: .bottom) { goalCard(plan) }
    }

    private func row(for day: PlanWeek.Day) -> some View {
        let calendar = Calendar.current
        return HLDayRow(
            weekday: PlanFormatting.shortWeekdayName(day.weekday),
            day: "\(calendar.component(.day, from: day.date))",
            title: day.workout.map(PlanFormatting.categories) ?? "",
            meta: meta(for: day),
            state: rowState(day.state),
            onStart: { viewModel.open(weekday: day.weekday) }
        )
        .contentShape(Rectangle())
        .onTapGesture { if day.workout != nil { viewModel.open(weekday: day.weekday) } }
    }

    private func meta(for day: PlanWeek.Day) -> String {
        guard let workout = day.workout else { return "" }
        return day.state == .done ? "✓ Done" : PlanFormatting.meta(of: workout)
    }

    private func rowState(_ state: PlanWeek.Day.State) -> HLDayRow.State {
        switch state {
        case .done: .done
        case .today: .today
        case .upcoming: .upcoming
        case .rest: .rest
        }
    }

    private func goalCard(_ plan: WorkoutPlan) -> some View {
        let title = viewModel.goalTitle(for: plan)
        return HLGroup {
            NavigationLink {
                GoalForecastView(plan: plan, goalTitle: title, now: viewModel.now())
            } label: {
                HLListRow(title: "Goal: \(title)", subtitle: PlanFormatting.goalSubtitle(of: plan), accessory: .chevron)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20).padding(.bottom, 12).padding(.top, 8)
        .background(HerLiftTheme.background)
    }
}
