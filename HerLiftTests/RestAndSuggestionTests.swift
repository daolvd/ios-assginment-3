import Foundation
import Testing
@testable import HerLift

@MainActor
struct NextSetSuggestionTests {
    @Test func aSetThatWasTooHardSuggestsOneStepLighter() {
        let suggestion = NextSetSuggestion.after(set("machine-chest-press", kg: 30, reps: 11, .tooHard), of: exercise("machine-chest-press"))

        #expect(suggestion == NextSetSuggestion(kind: .tooHard, currentKg: 30, suggestedKg: 27.5))
        #expect(suggestion?.message == "That was hard — try 27.5 kg for the next set. This only changes today.")
        #expect(suggestion?.useTitle == "Use 27.5 kg")
        #expect(suggestion?.keepTitle == "Keep 30 kg")
    }

    @Test func fewerRepsThanThePlanSuggestsOneStepLighter() {
        // Machine chest press asks for 10–12 reps.
        let short = NextSetSuggestion.after(set("machine-chest-press", kg: 30, reps: 9, .good), of: exercise("machine-chest-press"))
        #expect(short == NextSetSuggestion(kind: .belowTarget(minimumReps: 10), currentKg: 30, suggestedKg: 27.5))
        #expect(short?.message == "You didn't reach 10 reps — try 27.5 kg for the next set. This only changes today.")

        #expect(NextSetSuggestion.after(set("machine-chest-press", kg: 30, reps: 10, .good), of: exercise("machine-chest-press")) == nil)
    }

    @Test func anEasySetAtTheTopOfTheRepRangeSuggestsOneStepHeavier() {
        let heavier = NextSetSuggestion.after(set("machine-chest-press", kg: 30, reps: 12, .easy), of: exercise("machine-chest-press"))
        #expect(heavier == NextSetSuggestion(kind: .easy, currentKg: 30, suggestedKg: 32.5))
        #expect(heavier?.message == "That felt easy — try 32.5 kg for the next set. This only changes today.")

        #expect(NextSetSuggestion.after(set("machine-chest-press", kg: 30, reps: 11, .easy), of: exercise("machine-chest-press")) == nil)
        #expect(NextSetSuggestion.after(set("machine-chest-press", kg: 30, reps: 12, .good), of: exercise("machine-chest-press")) == nil)
        #expect(NextSetSuggestion.after(set("machine-chest-press", kg: 30, reps: 12, .hard), of: exercise("machine-chest-press")) == nil)
    }

    @Test func theStepDependsOnTheEquipment() {
        // Dumbbell shoulder press: 1 kg steps, 8–12 reps.
        let press = exercise("seated-dumbbell-shoulder-press")
        #expect(NextSetSuggestion.after(set(press.id, kg: 20, reps: 10, .tooHard), of: press)?.suggestedKg == 19)
        #expect(NextSetSuggestion.after(set(press.id, kg: 20, reps: 12, .easy), of: press)?.suggestedKg == 21)
        // Lat pulldown is a cable machine: 2.5 kg steps.
        let pulldown = exercise("lat-pulldown")
        #expect(NextSetSuggestion.after(set(pulldown.id, kg: 40, reps: 10, .tooHard), of: pulldown)?.suggestedKg == 37.5)
    }

    @Test func bodyweightExercisesAndWeightsThatWouldReachZeroGetNoSuggestion() {
        #expect(NextSetSuggestion.after(set("reverse-crunch", kg: 0, reps: 5, .tooHard), of: exercise("reverse-crunch")) == nil)
        #expect(NextSetSuggestion.after(set("machine-chest-press", kg: 2.5, reps: 10, .tooHard), of: exercise("machine-chest-press")) == nil)
        #expect(NextSetSuggestion.after(set("seated-dumbbell-shoulder-press", kg: 1, reps: 8, .tooHard), of: exercise("seated-dumbbell-shoulder-press")) == nil)
    }

    private func exercise(_ id: String) -> Exercise {
        try! JSONExerciseRepository().exercises.first { $0.id == id }!
    }

    private func set(_ id: String, kg: Double, reps: Int, _ effort: PerceivedEffort) -> LoggedSet {
        LoggedSet(exerciseID: id, setNumber: 1, weightKg: kg, repetitions: reps, effort: effort)
    }
}

@MainActor
struct RestViewModelTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()
    private var saturday: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 3, hour: 14))! }

    @Test func aSetIsFollowedByARestAsLongAsTheExerciseSays() throws {
        let viewModel = makeViewModel()
        let rest = try #require(complete(viewModel, kg: "20", reps: "11").rest)

        let seconds = workout().exercises[0].exercise.defaultRestSeconds
        #expect(rest.endsAt == saturday.addingTimeInterval(Double(seconds)))
        #expect(rest.next == WorkoutStep(exerciseIndex: 0, setNumber: 2))
        #expect(viewModel.restNextLine == "Next: Machine Chest Press · Set 2 of 3")
    }

    @Test func aHardSetOffersALighterWeightThatCanBeUsed() {
        let viewModel = makeViewModel()
        complete(viewModel, kg: "25", reps: "11", effort: .tooHard)
        #expect(viewModel.rest?.suggestion?.suggestedKg == 22.5)

        viewModel.useSuggestion()

        #expect(viewModel.weightText == "22.5")
        #expect(viewModel.targetLine == "Target 22.5 kg × 10–12")
        #expect(viewModel.rest?.suggestion == nil)
        #expect(viewModel.rest != nil) // still resting
    }

    @Test func keepingTheWeightLeavesItAsItWas() {
        let viewModel = makeViewModel()
        complete(viewModel, kg: "25", reps: "11", effort: .tooHard)

        viewModel.keepWeight()

        #expect(viewModel.weightText == "25")
        #expect(viewModel.targetLine == "Target 25 kg × 10–12")
        #expect(viewModel.rest?.suggestion == nil)
    }

    @Test func noSuggestionIsMadeForAnotherExerciseAndTheRestNamesIt() {
        let viewModel = makeViewModel()
        complete(viewModel, kg: "25", reps: "11")
        complete(viewModel, kg: "25", reps: "11")
        complete(viewModel, kg: "25", reps: "9", effort: .tooHard) // the third and last chest press set

        #expect(viewModel.rest?.suggestion == nil)
        #expect(viewModel.restNextLine == "Next: Reverse Crunch · Set 1 of 2")
    }

    @Test func thereIsNoRestAfterTheLastSet() {
        let viewModel = makeViewModel()
        for _ in 1...3 { complete(viewModel, kg: "25", reps: "11") }
        complete(viewModel, kg: "", reps: "12")
        #expect(viewModel.rest != nil)

        complete(viewModel, kg: "", reps: "12")

        #expect(viewModel.rest == nil)
        #expect(viewModel.isReadyToFinish)
    }

    @Test func skippingOrFinishingEndsTheRest() {
        let viewModel = makeViewModel()
        complete(viewModel, kg: "25", reps: "11")
        viewModel.endRest()
        #expect(viewModel.rest == nil)

        complete(viewModel, kg: "25", reps: "11")
        #expect(viewModel.finish())
        #expect(viewModel.rest == nil)
    }

    @discardableResult
    private func complete(
        _ viewModel: WorkoutSessionViewModel, kg: String, reps: String, effort: PerceivedEffort = .good
    ) -> WorkoutSessionViewModel {
        if viewModel.log == nil { viewModel.start() }
        viewModel.endRest()
        if viewModel.showsWeightField { viewModel.weightText = kg }
        viewModel.repsText = reps
        viewModel.effort = effort
        viewModel.completeSet()
        return viewModel
    }

    private func makeViewModel() -> WorkoutSessionViewModel {
        WorkoutSessionViewModel(
            workout: workout(), useCase: WorkoutSessionUseCase(sessions: SessionStoreStub(), calendar: calendar),
            editPlan: EditWorkoutPlanUseCase(
                plans: PlanStoreStub(plan: WorkoutPlan(goalID: "buildMuscle", workouts: [workout()], status: .active)),
                exercises: try! JSONExerciseRepository()),
            now: { saturday })
    }
}
