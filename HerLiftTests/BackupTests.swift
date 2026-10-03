import CloudKit
import Foundation
import Testing
@testable import HerLift

// MARK: - What is copied to iCloud

@MainActor
struct BackupTests {
    private final class CloudSpy: CloudBackupStoring {
        var uploads: [CloudBackup] = []
        var fails: BackupError?
        func upload(_ backup: CloudBackup) async throws(BackupError) {
            if let fails { throw fails }
            uploads.append(backup)
        }
    }

    private final class ProfileStore: OnboardingProfileRepository {
        var profile: OnboardingProfile?
        var fails = false
        func loadOnboardingProfile() throws -> OnboardingProfile? {
            if fails { throw CocoaError(.fileReadUnknown) }
            return profile
        }
        func saveOnboardingProfile(_ profile: OnboardingProfile) throws { self.profile = profile }
    }

    private let profile = OnboardingProfile(
        age: 29, heightCm: 165, weightKg: 80, experience: .beginner, trainingWeekdays: [1, 3, 6],
        sessionMinutes: 45, healthNote: "Sore knee", clearedByDoctor: true)

    private func makePlan() -> WorkoutPlan {
        var base = workout()
        base = PlannedWorkout(
            weekday: 6, categoryIDs: base.categoryIDs,
            exercises: base.exercises.map { var e = $0; e.targetWeightKg = $0.exercise.loadType == "bodyweight" ? nil : 20; return e })
        return WorkoutPlan(
            goalID: "loseFat", workouts: [base], status: .active,
            weightForecast: WeightLossForecast(currentKg: 80, targetKg: 70, earliestWeek: 20, latestWeek: 40),
            startedOn: Date(timeIntervalSince1970: 1_800_000_000))
    }

    private func makeUseCase(
        profile: OnboardingProfile?, plan: WorkoutPlan?, cloud: CloudSpy, profileFails: Bool = false
    ) -> BackupUseCase {
        let profiles = ProfileStore()
        profiles.profile = profile
        profiles.fails = profileFails
        return BackupUseCase(profiles: profiles, plans: PlanStoreStub(plan: plan), cloud: cloud)
    }

    @Test func answersAndPlanAreCopiedTogether() async throws {
        let cloud = CloudSpy()
        let plan = makePlan()
        let now = Date(timeIntervalSince1970: 1_800_100_000)

        try await makeUseCase(profile: profile, plan: plan, cloud: cloud).backUp(now: now)

        #expect(cloud.uploads == [CloudBackup(profile: profile, plan: plan, savedAt: now)])
    }

    @Test func withoutAPlanOnlyTheAnswersAreCopied() async throws {
        let cloud = CloudSpy()

        try await makeUseCase(profile: profile, plan: nil, cloud: cloud).backUp()

        #expect(cloud.uploads.first?.plan == nil)
    }

    @Test func withoutAnswersThereIsNothingToBackUp() async {
        let cloud = CloudSpy()

        await #expect(throws: BackupError.nothingToBackUp) {
            try await makeUseCase(profile: nil, plan: makePlan(), cloud: cloud).backUp()
        }
        #expect(cloud.uploads.isEmpty)
    }

    @Test func aStoreThatCannotBeReadSendsNothing() async {
        let cloud = CloudSpy()

        await #expect(throws: BackupError.couldNotReadData) {
            try await makeUseCase(profile: profile, plan: nil, cloud: cloud, profileFails: true).backUp()
        }
        #expect(cloud.uploads.isEmpty)
    }

    @Test func theCloudsErrorIsPassedOn() async {
        let cloud = CloudSpy()
        cloud.fails = .iCloudUnavailable

        await #expect(throws: BackupError.iCloudUnavailable) {
            try await makeUseCase(profile: profile, plan: nil, cloud: cloud).backUp()
        }
    }

    @Test func thePlanIsWrittenAsPlainDataByExerciseID() throws {
        let payload = PlanBackupPayload(makePlan())

        #expect(payload.goalID == "loseFat")
        #expect(payload.status == "active")
        #expect(payload.forecast == PlanBackupPayload.Forecast(currentKg: 80, targetKg: 70, earliestWeek: 20, latestWeek: 40))
        #expect(payload.workouts.first?.exercises.map(\.exerciseID) == ["machine-chest-press", "reverse-crunch"])
        #expect(payload.workouts.first?.exercises.map(\.targetWeightKg) == [20, nil])

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        #expect(try decoder.decode(PlanBackupPayload.self, from: Data(try payload.json().utf8)) == payload)
    }

    @Test func eachBackupReplacesTheOneBefore() throws {
        let backup = CloudBackup(profile: profile, plan: makePlan(), savedAt: Date())

        let records = try CloudKitBackupStore.records(for: backup)

        #expect(records.map(\.recordType) == ["Profile", "Plan"])
        #expect(records.map(\.recordID.recordName) == ["profile", "plan"])
        #expect(records[0]["age"] as? Int == 29)
        #expect(records[0]["healthNote"] as? String == "Sore knee")
        #expect(records[1]["goalID"] as? String == "loseFat")
        #expect(try CloudKitBackupStore.records(for: CloudBackup(profile: profile, plan: nil, savedAt: Date())).count == 1)
    }
}

// MARK: - Backing up by itself

@MainActor
struct AutomaticBackupTests {
    private final class CloudSpy: CloudBackupStoring {
        var uploads: [CloudBackup] = []
        var fails: BackupError?
        func upload(_ backup: CloudBackup) async throws(BackupError) {
            if let fails { throw fails }
            uploads.append(backup)
        }
    }

    private final class Profiles: OnboardingProfileRepository {
        var profile: OnboardingProfile? = OnboardingProfile(
            age: 29, heightCm: 165, weightKg: 80, experience: .beginner, trainingWeekdays: [1, 3],
            sessionMinutes: 45, healthNote: nil, clearedByDoctor: false)
        func loadOnboardingProfile() throws -> OnboardingProfile? { profile }
        func saveOnboardingProfile(_ profile: OnboardingProfile) throws { self.profile = profile }
    }

    /// A backup view model that does not wait before backing up.
    private func makeBackup(plans: PlanStoreStub, profiles: Profiles? = nil, cloud: CloudSpy) -> BackupViewModel {
        BackupViewModel(
            backup: BackupUseCase(profiles: profiles ?? Profiles(), plans: plans, cloud: cloud), wait: {})
    }

    private func plan(target: Double? = 20) -> WorkoutPlan {
        let base = workout(target: target)
        return WorkoutPlan(goalID: "buildMuscle", workouts: [base], status: .active)
    }

    @Test func aSavedPlanIsBackedUpWithoutAnyTap() async throws {
        let cloud = CloudSpy()
        let store = PlanStoreStub()
        let backup = makeBackup(plans: store, cloud: cloud)
        let plans = BackingUpWorkoutPlanRepository(store, planChanged: { backup.scheduleBackup() })

        try plans.savePlan(plan())
        await backup.waitUntilIdle()

        #expect(cloud.uploads.count == 1)
        #expect(cloud.uploads.first?.plan == plan())
        #expect(backup.state != .idle)
    }

    @Test func newTargetWeightsFromFeedbackReachTheCloudToo() async throws {
        let cloud = CloudSpy()
        let store = PlanStoreStub(plan: plan(target: 20))
        let backup = makeBackup(plans: store, cloud: cloud)
        let plans = BackingUpWorkoutPlanRepository(store, planChanged: { backup.scheduleBackup() })
        let editPlan = EditWorkoutPlanUseCase(plans: plans, exercises: try JSONExerciseRepository())

        _ = try editPlan.setTargetWeights([TargetWeightChange(weekday: 6, exerciseID: "machine-chest-press", weightKg: 22.5)])
        await backup.waitUntilIdle()

        #expect(cloud.uploads.last?.plan?.workouts.first?.exercises.first?.targetWeightKg == 22.5)
    }

    @Test func aDeletedPlanIsBackedUpAsNoPlan() async throws {
        let cloud = CloudSpy()
        let store = PlanStoreStub(plan: plan())
        let backup = makeBackup(plans: store, cloud: cloud)
        let plans = BackingUpWorkoutPlanRepository(store, planChanged: { backup.scheduleBackup() })

        try plans.deletePlan()
        await backup.waitUntilIdle()

        #expect(cloud.uploads.last?.plan == nil)
    }

    @Test func savedAnswersAreBackedUp() async throws {
        let cloud = CloudSpy()
        let profiles = Profiles()
        let backup = makeBackup(plans: PlanStoreStub(), profiles: profiles, cloud: cloud)
        let stored = BackingUpProfileRepository(profiles, profileChanged: { backup.scheduleBackup() })
        let changed = OnboardingProfile(
            age: 30, heightCm: 166, weightKg: 78, experience: .some, trainingWeekdays: [2, 4],
            sessionMinutes: 60, healthNote: nil, clearedByDoctor: false)

        try stored.saveOnboardingProfile(changed)
        await backup.waitUntilIdle()

        #expect(cloud.uploads.last?.profile == changed)
    }

    @Test func readingNeverTriggersABackup() async throws {
        let cloud = CloudSpy()
        let store = PlanStoreStub(plan: plan())
        let backup = makeBackup(plans: store, cloud: cloud)
        let plans = BackingUpWorkoutPlanRepository(store, planChanged: { backup.scheduleBackup() })

        _ = try plans.loadPlan()
        await backup.waitUntilIdle()

        #expect(cloud.uploads.isEmpty)
    }

    @Test func aFailedSaveIsNotBackedUp() async throws {
        let cloud = CloudSpy()
        let store = PlanStoreStub()
        store.failsOnSave = true
        let backup = makeBackup(plans: store, cloud: cloud)
        let plans = BackingUpWorkoutPlanRepository(store, planChanged: { backup.scheduleBackup() })

        #expect(throws: Error.self) { try plans.savePlan(plan()) }
        await backup.waitUntilIdle()

        #expect(cloud.uploads.isEmpty)
    }

    @Test func aFailureShowsWhyAndTheNextTryCanSucceed() async throws {
        let cloud = CloudSpy()
        cloud.fails = .offline
        let backup = makeBackup(plans: PlanStoreStub(plan: plan()), cloud: cloud)

        backup.scheduleBackup()
        await backup.waitUntilIdle()
        #expect(backup.state == .failed(.offline))

        cloud.fails = nil
        backup.retryIfFailed()
        await backup.waitUntilIdle()
        guard case .done = backup.state else {
            Issue.record("Expected a finished backup, got \(backup.state)")
            return
        }
    }

    @Test func retryDoesNothingWhenTheLastBackupWorked() async throws {
        let cloud = CloudSpy()
        let backup = makeBackup(plans: PlanStoreStub(plan: plan()), cloud: cloud)
        await backup.backUpNow()

        backup.retryIfFailed()
        await backup.waitUntilIdle()

        #expect(cloud.uploads.count == 1)
    }

    @Test func nothingToBackUpYetIsNotAnError() async throws {
        let cloud = CloudSpy()
        let profiles = Profiles()
        profiles.profile = nil
        let backup = makeBackup(plans: PlanStoreStub(), profiles: profiles, cloud: cloud)

        backup.scheduleBackup()
        await backup.waitUntilIdle()

        #expect(backup.state == .idle)
        #expect(cloud.uploads.isEmpty)
    }

    @Test func theProfileScreenShowsTheBackupState() async throws {
        let cloud = CloudSpy()
        cloud.fails = .iCloudUnavailable
        let backup = makeBackup(plans: PlanStoreStub(plan: plan()), cloud: cloud)
        let exercises = try JSONExerciseRepository()
        let profiles = Profiles()
        let viewModel = ProfileViewModel(
            editor: OnboardingViewModel(goals: onboardingPreviewGoals),
            loadProfile: LoadOnboardingProfileUseCase(repository: profiles),
            editPlan: EditWorkoutPlanUseCase(plans: PlanStoreStub(), exercises: exercises), backup: backup)
        #expect(viewModel.backupState == .idle)

        await viewModel.backUpNow()

        #expect(viewModel.backupState == .failed(.iCloudUnavailable))
    }
}
