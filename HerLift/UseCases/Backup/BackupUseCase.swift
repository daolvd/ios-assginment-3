import Foundation

nonisolated enum BackupError: LocalizedError, Equatable {
    case nothingToBackUp
    case couldNotReadData
    case iCloudUnavailable
    /// The app has no access to its iCloud container: the capability or the container is missing or wrong.
    case iCloudNotSetUp
    case offline
    case iCloudFull
    case couldNotBackUp

    var errorDescription: String? {
        switch self {
        case .nothingToBackUp: "There's nothing to back up yet."
        case .couldNotReadData: "We couldn't read your profile."
        case .iCloudUnavailable: "You're not signed in to iCloud on this phone."
        case .iCloudNotSetUp: "HerLift can't use its iCloud container."
        case .offline: "You're offline."
        case .iCloudFull: "Your iCloud storage is full."
        case .couldNotBackUp: "We couldn't back up to iCloud."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .nothingToBackUp: "Finish the setup questions first."
        case .couldNotReadData: "Close the app and open it again."
        case .iCloudUnavailable: "Open Settings, tap your name and sign in to iCloud, then try again."
        case .iCloudNotSetUp: "Check the iCloud capability and its container in the app's settings."
        case .offline: "Connect to the internet and try again."
        case .iCloudFull: "Free some iCloud storage in Settings, then try again."
        case .couldNotBackUp: "Try again in a moment."
        }
    }
}

/// Her iCloud, which holds one copy of her answers and one of her plan; a new backup replaces the old one.
@MainActor
protocol CloudBackupStoring {
    func upload(_ backup: CloudBackup) async throws(BackupError)
}

/// Copies her answers and her plan to her own iCloud when she asks. Nothing is sent otherwise.
@MainActor
struct BackupUseCase {
    private let profiles: any OnboardingProfileRepository
    private let plans: any WorkoutPlanRepository
    private let cloud: any CloudBackupStoring

    init(profiles: any OnboardingProfileRepository, plans: any WorkoutPlanRepository, cloud: any CloudBackupStoring) {
        self.profiles = profiles
        self.plans = plans
        self.cloud = cloud
    }

    func backUp(now: Date = Date()) async throws(BackupError) {
        let profile: OnboardingProfile?
        let plan: WorkoutPlan?
        do {
            profile = try profiles.loadOnboardingProfile()
            plan = try plans.loadPlan()
        } catch {
            throw .couldNotReadData
        }
        guard let profile else { throw .nothingToBackUp }
        try await cloud.upload(CloudBackup(profile: profile, plan: plan, savedAt: now))
    }
}
