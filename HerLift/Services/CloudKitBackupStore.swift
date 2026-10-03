import CloudKit
import Foundation

/// Keeps the backup in the private database of her own iCloud account, so no sign-in screen is needed and nobody
/// else, including the developer, can read it. It uses the app's first iCloud container.
@MainActor
struct CloudKitBackupStore: CloudBackupStoring {
    static let profileRecordName = "profile"
    static let planRecordName = "plan"

    func upload(_ backup: CloudBackup) async throws(BackupError) {
        // Without the iCloud capability or an iCloud account the token is nil. Asking for the container before the
        // capability exists would crash the app, so this check comes first.
        guard FileManager.default.ubiquityIdentityToken != nil else { throw .iCloudUnavailable }
        let container = CKContainer.default()
        do {
            guard try await container.accountStatus() == .available else { throw BackupError.iCloudUnavailable }
            let records = try Self.records(for: backup)
            // Without a plan the old plan record goes; deleting one that is not there is not an error.
            let gone = backup.plan == nil ? [CKRecord.ID(recordName: Self.planRecordName)] : []
            let results = try await container.privateCloudDatabase.modifyRecords(
                saving: records, deleting: gone, savePolicy: .allKeys, atomically: false)
            for (_, result) in results.saveResults {
                if case .failure(let error) = result { throw error }
            }
        } catch let error as BackupError {
            throw error
        } catch let error as CKError {
            throw Self.backupError(for: error)
        } catch {
            throw .couldNotBackUp
        }
    }

    /// One record for her answers and one for her plan, each with a fixed name so a new backup replaces the old.
    static func records(for backup: CloudBackup) throws -> [CKRecord] {
        let profile = CKRecord(recordType: "Profile", recordID: CKRecord.ID(recordName: profileRecordName))
        profile["age"] = backup.profile.age
        profile["heightCm"] = backup.profile.heightCm
        profile["weightKg"] = backup.profile.weightKg
        profile["experience"] = backup.profile.experience.rawValue
        profile["trainingWeekdays"] = backup.profile.trainingWeekdays
        profile["sessionMinutes"] = backup.profile.sessionMinutes
        profile["healthNote"] = backup.profile.healthNote
        profile["clearedByDoctor"] = backup.profile.clearedByDoctor ? 1 : 0
        profile["savedAt"] = backup.savedAt

        guard let plan = backup.plan else { return [profile] }
        let record = CKRecord(recordType: "Plan", recordID: CKRecord.ID(recordName: planRecordName))
        record["goalID"] = plan.goalID
        record["status"] = plan.status.rawValue
        record["startedOn"] = plan.startedOn
        record["payload"] = try PlanBackupPayload(plan).json()
        record["savedAt"] = backup.savedAt
        return [profile, record]
    }

    private static func backupError(for error: CKError) -> BackupError {
        switch error.code {
        case .notAuthenticated, .permissionFailure, .badContainer, .missingEntitlement: .iCloudUnavailable
        case .networkUnavailable, .networkFailure: .offline
        case .quotaExceeded: .iCloudFull
        default: .couldNotBackUp
        }
    }
}
