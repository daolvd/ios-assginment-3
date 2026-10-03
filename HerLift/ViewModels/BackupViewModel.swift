import Foundation
import Observation

/// Keeps the copy of her answers and plan in iCloud up to date. A change asks for a backup; changes that come
/// close together become one backup after a short wait, and a change during a backup asks for one more after it.
@MainActor
@Observable
final class BackupViewModel {
    /// Where the copy in iCloud stands.
    enum State: Equatable {
        case idle
        case backingUp
        case done(Date)
        case failed(BackupError)
    }

    private(set) var state = State.idle
    @ObservationIgnored private let backup: BackupUseCase?
    /// The wait before a backup, so a burst of changes is saved once.
    @ObservationIgnored private let wait: @Sendable () async -> Void
    @ObservationIgnored private var scheduled: Task<Void, Never>?
    @ObservationIgnored private var isRunning = false
    @ObservationIgnored private var changedWhileRunning = false

    init(
        backup: BackupUseCase?,
        wait: @escaping @Sendable () async -> Void = { try? await Task.sleep(for: .seconds(2)) }
    ) {
        self.backup = backup
        self.wait = wait
    }

    /// Something she keeps in iCloud changed: back up soon.
    func scheduleBackup() {
        guard backup != nil else { return }
        if isRunning {
            changedWhileRunning = true
            return
        }
        scheduled?.cancel()
        scheduled = Task { [weak self, wait] in
            await wait()
            guard !Task.isCancelled else { return }
            await self?.run()
        }
    }

    /// The Back up now button: backs up straight away.
    func backUpNow() async {
        guard backup != nil, !isRunning else { return }
        scheduled?.cancel()
        await run()
    }

    /// Tries again after a failure, such as when she was offline or iCloud was signed out.
    func retryIfFailed() {
        if case .failed = state { scheduleBackup() }
    }

    /// Waits until nothing is scheduled or running.
    func waitUntilIdle() async {
        while let task = scheduled {
            await task.value
            if scheduled == task { scheduled = nil }
        }
    }

    private func run() async {
        guard let backup else { return }
        isRunning = true
        state = .backingUp
        do {
            try await backup.backUp()
            state = .done(Date())
        } catch BackupError.nothingToBackUp {
            state = .idle
        } catch {
            state = .failed(error)
        }
        isRunning = false
        if changedWhileRunning {
            changedWhileRunning = false
            scheduleBackup()
        }
    }
}
