import Foundation

/// Builds a week of workouts from the training pattern and the exercise catalogue:
/// pattern → one muscle-group session per training day → cover every muscle group in the week →
/// eligible exercises → fill the time with sets → validate → save as the current plan, waiting for her to accept it.
@MainActor
struct CreateWorkoutPlanUseCase {
    /// Monday = 1 … Sunday = 7.
    static let weekdays = 1...7
    /// At least two training days: one day a week cannot cover the whole body.
    static let supportedDayCounts = 2...7
    static let supportedSessionMinutes = 20...120

    let patterns: any TrainingPatternRepository
    let exercises: any ExerciseRepository
    let plans: any WorkoutPlanRepository
    var validator = WorkoutPlanValidator()

    func execute(for user: UserPlanningProfile) throws(PlanningError) -> WorkoutPlan {
        try validateInput(user)
        try requireClearanceIfNeeded(user)
        let weightForecast = try ForecastCalculator.weightLossForecast(for: user)
        guard let pattern = pattern(for: user.level) else { throw .patternNotFound }

        let eligible = exercises.exercises.filter { ExerciseEligibility.isAllowed($0, for: user) }
        let days = user.trainingDays.sorted()

        // The pattern is a cycle: with more training days than groups, start again from the first group.
        let groups = days.indices.map { pattern.sessionGroups[$0 % pattern.sessionGroups.count].categoryIDs }

        var workouts: [PlannedWorkout] = []
        for (weekday, categoryIDs) in zip(days, coveringEveryMuscleGroup(groups, eligible: eligible)) {
            workouts.append(makeWorkout(weekday: weekday, categoryIDs: categoryIDs, eligible: eligible,
                                        maxMinutes: user.sessionMinutes))
        }

        let plan = WorkoutPlan(goalID: user.goalID, workouts: workouts, status: .draft, weightForecast: weightForecast)
        try validator.validate(plan, for: user)

        // The new plan replaces the current one. Nothing is stored unless every step above succeeded.
        do { try plans.savePlan(plan) } catch { throw .couldNotSavePlan }
        return plan
    }

    // MARK: Steps

    private func validateInput(_ user: UserPlanningProfile) throws(PlanningError) {
        let days = user.trainingDays
        guard Self.supportedDayCounts.contains(days.count),
              Set(days).count == days.count,
              days.allSatisfy({ Self.weekdays.contains($0) })
        else { throw .unsupportedTrainingDays }
        guard Self.supportedSessionMinutes.contains(user.sessionMinutes) else { throw .unsupportedSessionMinutes }
    }

    /// Anyone who reported a health concern needs a doctor's clearance before a plan is built.
    private func requireClearanceIfNeeded(_ user: UserPlanningProfile) throws(PlanningError) {
        guard !user.reportsHealthConcern || user.clearedByDoctor else { throw .medicalClearanceRequired }
    }

    /// The most advanced pattern that is not above the person's level.
    private func pattern(for level: TrainingLevel) -> TrainingPattern? {
        patterns.patterns
            .filter { $0.level <= level && !$0.sessionGroups.isEmpty }
            .max { $0.level < $1.level }
    }

    /// A short week can leave core out of every group (three training days: six main categories).
    /// Core may be added on top of a workout's two main categories, so it joins the last workout.
    /// Other muscle groups are never added, so a week of one or two days can still miss some.
    private func coveringEveryMuscleGroup(_ groups: [[Category.ID]], eligible: [Exercise]) -> [[Category.ID]] {
        let coreIsEligible = eligible.contains { $0.categoryID == Category.coreID }
        let coreIsPlanned = groups.contains { $0.contains(Category.coreID) }
        guard coreIsEligible, !coreIsPlanned, !groups.isEmpty else { return groups }

        var covered = groups
        covered[covered.count - 1].append(Category.coreID)
        return covered
    }

    private func makeWorkout(
        weekday: Int, categoryIDs: [Category.ID], eligible: [Exercise], maxMinutes: Int
    ) -> PlannedWorkout {
        let candidates = eligible.filter { categoryIDs.contains($0.categoryID) }
        let selected = fill(interleaved(candidates, categoryIDs: categoryIDs), categoryIDs: categoryIDs,
                            maxSeconds: maxMinutes * 60)
        return PlannedWorkout(weekday: weekday, categoryIDs: categoryIDs, exercises: selected)
    }

    /// Catalogue order inside each category, then one exercise from each category in turn
    /// (first of A, first of B, second of A, second of B, …).
    private func interleaved(_ candidates: [Exercise], categoryIDs: [Category.ID]) -> [Exercise] {
        let perCategory = categoryIDs.map { id in candidates.filter { $0.categoryID == id } }
        let rounds = perCategory.map(\.count).max() ?? 0
        return (0..<rounds).flatMap { round in
            perCategory.compactMap { round < $0.count ? $0[round] : nil }
        }
    }

    /// Fills the session in this order:
    /// 1. the first exercise of every category, at the baseline number of sets;
    /// 2. extra sets for those exercises, one at a time in turn, up to the maximum;
    /// 3. each further exercise that still fits at the baseline sets, followed by extra sets again.
    /// Anything that does not fit in the remaining time is skipped.
    private func fill(_ ordered: [Exercise], categoryIDs: [Category.ID], maxSeconds: Int) -> [WorkoutExercise] {
        let firstOfEachCategory = categoryIDs.compactMap { id in ordered.first { $0.categoryID == id } }
        let others = ordered.filter { !firstOfEachCategory.contains($0) }

        var selected: [WorkoutExercise] = []
        for exercise in firstOfEachCategory {
            addIfItFits(exercise, to: &selected, maxSeconds: maxSeconds)
        }
        addSets(to: &selected, maxSeconds: maxSeconds)

        for exercise in others {
            if addIfItFits(exercise, to: &selected, maxSeconds: maxSeconds) {
                addSets(to: &selected, maxSeconds: maxSeconds)
            }
        }
        return selected
    }

    @discardableResult
    private func addIfItFits(_ exercise: Exercise, to selected: inout [WorkoutExercise], maxSeconds: Int) -> Bool {
        let planned = WorkoutExercise(exercise: exercise, sets: WorkoutExercise.baselineSets)
        guard selected.reduce(0, { $0 + $1.seconds }) + planned.seconds <= maxSeconds else { return false }
        selected.append(planned)
        return true
    }

    private func addSets(to selected: inout [WorkoutExercise], maxSeconds: Int) {
        var added = true
        while added {
            added = false
            for index in selected.indices where selected[index].sets < WorkoutExercise.maximumSets {
                let total = selected.reduce(0) { $0 + $1.seconds }
                if total + selected[index].secondsPerSet <= maxSeconds {
                    selected[index].sets += 1
                    added = true
                }
            }
        }
    }
}
