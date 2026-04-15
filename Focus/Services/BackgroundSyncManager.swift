import Foundation
import BackgroundTasks
import SwiftData

// MARK: - BackgroundSyncManager

/// Manages background sync of security alerts, codeowners, and contribution data.
///
/// Security alerts and codeowners sync on an 8-hour cadence.
/// Member contribution data syncs on a 24-hour cadence.
///
/// Call ``setup(modelContainer:tokenProvider:)`` once at app launch to register the
/// `BGProcessingTask` handler, then call ``syncIfNeeded(context:)`` whenever the app
/// returns to the foreground.
@Observable
@MainActor
final class BackgroundSyncManager {

    // MARK: - Properties

    /// The `BGProcessingTask` identifier registered with the system.
    static let taskIdentifier = "com.danberry.Focus.sync"

    /// The minimum elapsed time between security alert and codeowner syncs.
    static let securitySyncInterval: TimeInterval = 8 * 60 * 60    // 8 hours

    /// The minimum elapsed time between member contribution syncs.
    static let contributionSyncInterval: TimeInterval = 24 * 60 * 60 // 24 hours

    /// The `UserDefaults` key used to persist the last security sync timestamp.
    static let lastSyncedAtKey = "com.danberry.Focus.lastSyncedAt"

    /// The `UserDefaults` key used to persist the last contribution sync timestamp.
    static let lastContributionSyncedAtKey = "com.danberry.Focus.lastContributionSyncedAt"

    /// Whether a sync operation is currently in progress.
    private(set) var isSyncing = false

    /// The number of repositories that have completed syncing in the current pass.
    private(set) var syncCurrent: Int = 0

    /// The total number of repositories to sync in the current pass.
    private(set) var syncTotal: Int = 0

    /// The date of the most recent completed security sync, or `nil` if never synced.
    private(set) var lastSyncedAt: Date?

    /// The date of the most recent completed contribution sync, or `nil` if never synced.
    private(set) var lastContributionSyncedAt: Date?

    /// The SwiftData model container, injected during ``setup(modelContainer:tokenProvider:)``.
    private var modelContainer: ModelContainer?

    /// A closure that returns the current GitHub personal access token, injected during ``setup(modelContainer:tokenProvider:)``.
    private var tokenProvider: (@Sendable () -> String?)?

    /// Whether ``setup(modelContainer:tokenProvider:)`` has been called.
    private var isSetup = false

    // MARK: - Init

    /// Creates a new `BackgroundSyncManager`, restoring last sync timestamps from `UserDefaults`.
    init() {
        lastSyncedAt = UserDefaults.standard.object(forKey: Self.lastSyncedAtKey) as? Date
        lastContributionSyncedAt = UserDefaults.standard.object(forKey: Self.lastContributionSyncedAtKey) as? Date
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
        request.earliestBeginDate = Date(timeIntervalSinceNow: Self.securitySyncInterval)
        try? BGTaskScheduler.shared.submit(request)
    }

    // MARK: - Foreground Sync

    /// Syncs if security alerts are stale (>8 hours) or contributions are stale (>24 hours).
    func syncIfNeeded(context: ModelContext) async {
        guard isSetup, !isSyncing else { return }
        let securityStale = lastSyncedAt.map { Date.now.timeIntervalSince($0) >= Self.securitySyncInterval } ?? true
        let contributionsStale = lastContributionSyncedAt.map { Date.now.timeIntervalSince($0) >= Self.contributionSyncInterval } ?? true
        guard securityStale || contributionsStale else { return }
        await sync(context: context)
    }

    // MARK: - Private

    /// Performs a full sync of security, codeowners, velocity, and pull request data, then syncs
    /// contributions if the 24-hour window has elapsed.
    private func sync(context: ModelContext) async {
        guard let tokenProvider, !isSyncing else { return }
        isSyncing = true
        syncCurrent = 0
        syncTotal = 0
        defer { isSyncing = false }

        // Security + codeowners + velocity — always sync on every invocation.
        let rest = RESTClient(tokenProvider: tokenProvider)
        let graphQL = GraphQLClient(tokenProvider: tokenProvider)
        let syncService = SyncService(
            securityService: SecurityService(rest: rest),
            codeownersService: CodeownersService(rest: rest),
            velocityService: VelocityService(graphQL: graphQL),
            pullRequestService: PullRequestService(graphQL: graphQL)
        )
        await syncService.syncAll(in: context) { current, total in
            self.syncCurrent = current
            self.syncTotal = total
        }
        lastSyncedAt = .now
        UserDefaults.standard.set(lastSyncedAt, forKey: Self.lastSyncedAtKey)

        // Contributions — sync only when the 24-hour window has elapsed.
        let contributionsStale = lastContributionSyncedAt.map { Date.now.timeIntervalSince($0) >= Self.contributionSyncInterval } ?? true
        if contributionsStale {
            let graphQL = GraphQLClient(tokenProvider: tokenProvider)
            await syncAllContributions(using: ContributionService(graphQL: graphQL), in: context)
            lastContributionSyncedAt = .now
            UserDefaults.standard.set(lastContributionSyncedAt, forKey: Self.lastContributionSyncedAtKey)
        }

        scheduleNextSync()
    }

    /// Fetches and persists contributions for every ``Member`` in the given context.
    private func syncAllContributions(using service: ContributionService, in context: ModelContext) async {
        let members: [Member]
        let organizations: [SavedOrganization]
        do {
            members = try context.fetch(FetchDescriptor<Member>())
            organizations = try context.fetch(FetchDescriptor<SavedOrganization>())
        } catch {
            return
        }

        let organizationIDs = organizations.map(\.githubId)

        for member in members {
            guard let login = member.githubLogin else { continue }
            await service.syncContributions(login: login, member: member, organizationIDs: organizationIDs, in: context)
        }
    }

    /// Fulfills a `BGProcessingTask` by scheduling the next background run then performing a full sync.
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
