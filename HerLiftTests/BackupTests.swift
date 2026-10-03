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
