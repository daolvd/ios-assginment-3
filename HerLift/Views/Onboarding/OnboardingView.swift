//
//  OnboardingView.swift
//  HerLift
//
//  Created by Van Dao Le on 1/10/2026.
//

import SwiftUI

struct OnboardingView: View {
    enum Page { case about, training, goal }

    let goals: [Goal]
    var onBuildPlan: (() -> Void)?

    @State private var page: Int
    @State private var showsGoal: Bool
    @State private var age: String
    @State private var height: String
    @State private var weight: String
    @State private var experience = AboutYouView.Experience.beginner
    @State private var trainingDays: Set<Int> = [1, 3, 6]
    @State private var minutes = 45
    @State private var healthNote: String
    @State private var clearedByDoctor = false
    @State private var selectedGoalID: Goal.ID?
    @State private var targetWeight = ""
    @FocusState private var focusedField: OnboardingField?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(goals: [Goal], initialPage: Page = .about,
         age: String = "", height: String = "", weight: String = "",
         healthNote: String = "", selectedGoalID: Goal.ID? = nil,
         onBuildPlan: (() -> Void)? = nil) {
        self.goals = goals
        self.onBuildPlan = onBuildPlan
        _page = State(initialValue: initialPage == .about ? 0 : 1)
        _showsGoal = State(initialValue: initialPage == .goal)
        _age = State(initialValue: age)
        _height = State(initialValue: height)
        _weight = State(initialValue: weight)
        _healthNote = State(initialValue: healthNote)
        _selectedGoalID = State(initialValue: selectedGoalID)
    }

    var body: some View {
        NavigationStack {
            TabView(selection: $page) {
                AboutYouView(age: $age, height: $height, weight: $weight,
                             experience: $experience, focusedField: $focusedField).tag(0)
                YourTrainingView(trainingDays: $trainingDays, minutes: $minutes,
                                 healthNote: $healthNote, clearedByDoctor: $clearedByDoctor,
                                 focusedField: $focusedField).tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .background(HerLiftTheme.background)
            .navigationTitle(page == 0 ? "About you" : "Your training")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { stepCounter(1) }
                    .sharedBackgroundVisibility(.hidden)
                if page == 1 {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Back", systemImage: "chevron.left") { changePage(to: 0) }
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
            .safeAreaInset(edge: .bottom) {
                OnboardingStyle.primaryButton(page == 0 ? "Next" : "Continue") {
                    focusedField = nil
                    if page == 0 { changePage(to: 1) }
                    else { showsGoal = true }
                }
                .padding(.horizontal, 20).padding(.bottom, 12)
                .background(HerLiftTheme.background)
            }
            .navigationDestination(isPresented: $showsGoal) {
                YourGoalView(goals: goals, selectedGoalID: $selectedGoalID,
                             targetWeight: $targetWeight, focusedField: $focusedField,
                             onBuildPlan: onBuildPlan)
            }
            .onChange(of: page) { focusedField = nil }
        }
        .tint(HerLiftTheme.primary)
    }

    private func stepCounter(_ step: Int) -> some View {
        Text("\(step) of 2").font(.footnote).foregroundStyle(HerLiftTheme.secondaryText)
            .accessibilityLabel("Step \(step) of 2")
    }

    private func changePage(to nextPage: Int) {
        focusedField = nil
        withAnimation(reduceMotion ? nil : .easeInOut) { page = nextPage }
    }
}

enum OnboardingField: Hashable { case age, height, weight, health, targetWeight }

struct OnboardingPageContent<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            content().frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 44)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(HerLiftTheme.background)
        .foregroundStyle(HerLiftTheme.text)
    }
}

struct OnboardingNumberField: View {
    let title: String
    @Binding var text: String
    let prompt: String
    var unit: String? = nil
    var focusedField: FocusState<OnboardingField?>.Binding
    let field: OnboardingField
    var keyboard: UIKeyboardType = .decimalPad

    init(_ title: String, text: Binding<String>, prompt: String, unit: String? = nil,
         focusedField: FocusState<OnboardingField?>.Binding, field: OnboardingField,
         keyboard: UIKeyboardType = .decimalPad) {
        self.title = title
        _text = text
        self.prompt = prompt
        self.unit = unit
        self.focusedField = focusedField
        self.field = field
        self.keyboard = keyboard
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            OnboardingStyle.fieldLabel(title)
            HStack(spacing: 6) {
                TextField(title, text: $text, prompt: Text(prompt).foregroundStyle(HerLiftTheme.secondaryText))
                    .font(.headline).keyboardType(keyboard)
                    .focused(focusedField, equals: field)
                    .accessibilityLabel(unit.map { "\(title), \($0)" } ?? title)
                if let unit { OnboardingStyle.subtitle(unit) }
            }
            .padding(.horizontal, 14).frame(minHeight: 52)
            .background(HerLiftTheme.surface, in: RoundedRectangle(cornerRadius: 12))
        }
        .frame(maxWidth: .infinity)
    }
}

enum OnboardingStyle {
    static func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.headline).frame(maxWidth: .infinity, minHeight: 30)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: 14))
        .controlSize(.large)
    }

    static func fieldLabel(_ text: String) -> some View {
        Text(text).font(.footnote.weight(.medium)).foregroundStyle(HerLiftTheme.secondaryText)
    }

    static func subtitle(_ text: String) -> some View {
        Text(text).font(.subheadline).foregroundStyle(HerLiftTheme.secondaryText)
    }

    static func helper(_ text: String) -> some View {
        Text(text).font(.footnote).foregroundStyle(HerLiftTheme.secondaryText)
    }
}

let onboardingPreviewGoals = [
    Goal(id: "loseFat", title: "Lose fat", requiresTargetWeight: true),
    Goal(id: "buildMuscle", title: "Build muscle", requiresTargetWeight: false),
    Goal(id: "buildStrength", title: "Get stronger", requiresTargetWeight: false),
    Goal(id: "increaseGymConfidence", title: "Feel confident in the gym", requiresTargetWeight: false)
]

#Preview("Onboarding") {
    OnboardingView(goals: onboardingPreviewGoals)
}
