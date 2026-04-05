import Foundation
import BackgroundTasks
import SwiftData

// MARK: - BackgroundSyncManager

/// Manages the 8-hour background sync of security alerts and codeowners for all saved repositories.
///
/// Call ``setup(modelContainer:tokenProvider:)`` once at app launch to register the
/// `BGProcessingTask` handler, then call ``syncIfNeeded(context:)`` whenever the app
/// returns to the foreground.
@Observable
@MainActor
final class BackgroundSyncManager {

    // MARK: - Constants

    static let taskIdentifier = "com.danberry.Focus.sync"
    private static let syncInterval: TimeInterval = 8 * 60 * 60  // 8 hours
    private static let lastSyncedAtKey = "com.danberry.Focus.lastSyncedAt"

    // MARK: - State

    private(set) var isSyncing = false
    private(set) var lastSyncedAt: Date?

    // MARK: - Dependencies (set during setup)

    private var modelContainer: ModelContainer?
    private var tokenProvider: (@Sendable () -> String?)?
    private var isSetup = false

    // MARK: - Init

    init() {
        lastSyncedAt = UserDefaults.standard.object(forKey: Self.lastSyncedAtKey) as? Date
    }

    // MARK: - Setup

    /// Registers the `BGProcessingTask` handler. Must be called before the app finishes launching.
    func setup(modelContainer: ModelContainer, tokenProvider: @escaping @Sendable () -> String?) {
        self.modelContainer = modelContainer
        self.tokenProvider = tokenProvider
        self.isSetup = true

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.taskIdentifier,
            using: nil
        ) { [weak self] task in
            guard let processingTask = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }

            let syncTask = Task { @MainActor [weak self] in
                await self?.handleBackgroundTask(processingTask)
            }

            processingTask.expirationHandler = {
                syncTask.cancel()
            }
        }
    }

    // MARK: - Scheduling

    /// Submits a `BGProcessingTask` request to fire no earlier than 8 hours from now.
    func scheduleNextSync() {
        let request = BGProcessingTaskRequest(identifier: Self.taskIdentifier)
        request.requiresNetworkConnectivity = true
        request.earliestBeginDate = Date(timeIntervalSinceNow: Self.syncInterval)
        try? BGTaskScheduler.shared.submit(request)
    }

    // MARK: - Foreground Sync

    /// Syncs if no successful sync has occurred in the last 8 hours.
    func syncIfNeeded(context: ModelContext) async {
        guard isSetup, !isSyncing else { return }
        if let last = lastSyncedAt, Date.now.timeIntervalSince(last) < Self.syncInterval {
            return
        }
        await sync(context: context)
    }

    // MARK: - Private

    private func sync(context: ModelContext) async {
        guard let tokenProvider, !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        let rest = RESTClient(tokenProvider: tokenProvider)
        let service = SyncService(
            securityService: SecurityService(rest: rest),
            codeownersService: CodeownersService(rest: rest)
        )

        await service.syncAll(in: context)

        lastSyncedAt = .now
        UserDefaults.standard.set(lastSyncedAt, forKey: Self.lastSyncedAtKey)
        scheduleNextSync()
    }

    private func handleBackgroundTask(_ task: BGProcessingTask) async {
        guard let container = modelContainer else {
            task.setTaskCompleted(success: false)
            return
        }

        // Schedule the next run before starting work so it's registered
        // even if the current task is cut short by the system.
        scheduleNextSync()

        let context = ModelContext(container)
        await sync(context: context)
        task.setTaskCompleted(success: true)
    }
}
