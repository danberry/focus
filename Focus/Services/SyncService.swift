import Foundation
import SwiftData

// MARK: - SyncService

/// Orchestrates a full data sync for every saved repository.
///
/// `SyncService` coordinates ``SecurityService``, ``CodeownersService``,
/// ``VelocityService``, and ``PullRequestService``, then derives badge counts
/// from the freshly written SwiftData relationships.
///
/// Repositories are synced in parallel (up to ``maxConcurrentRepos`` at once).
/// Within each repository all six sub-service calls are issued concurrently via
/// `async let`. Network I/O for up to `maxConcurrentRepos × 6` requests runs in
/// parallel; all SwiftData writes are serialized on the main actor.
///
/// All operations run on the main actor.
@MainActor
struct SyncService: Sendable {

    // MARK: - Properties

    /// The service used to sync security alert data.
    private let securityService: SecurityService

    /// The service used to sync codeowner data.
    private let codeownersService: CodeownersService

    /// The service used to sync velocity metrics.
    private let velocityService: VelocityService

    /// The service used to sync open pull requests.
    private let pullRequestService: PullRequestService

    // MARK: - Init

    /// Creates a `SyncService` with the four domain services it coordinates.
    init(securityService: SecurityService, codeownersService: CodeownersService, velocityService: VelocityService, pullRequestService: PullRequestService) {
        self.securityService = securityService
        self.codeownersService = codeownersService
        self.velocityService = velocityService
        self.pullRequestService = pullRequestService
    }

    // MARK: - Sync

    /// The maximum number of repositories synced concurrently.
    static let maxConcurrentRepos = 8

    /// Syncs all saved repositories concurrently (up to ``maxConcurrentRepos`` at once),
    /// then saves the model context.
    ///
    /// Each repository's six sub-service network requests run in parallel. A sliding
    /// window ensures at most ``maxConcurrentRepos`` repositories are in-flight simultaneously.
    /// A failure to fetch the repository list is silently discarded and the method returns
    /// without syncing. Individual sub-service errors are handled within each service.
    ///
    /// - Parameters:
    ///   - context: The SwiftData model context used to fetch and persist repositories.
    ///   - onProgress: An optional closure called after each repository finishes syncing.
    ///     Receives the number of repositories completed so far and the total count.
    func syncAll(in context: ModelContext, onProgress: ((Int, Int) -> Void)? = nil) async {
        let repositories: [SavedRepository]
        do {
            repositories = try context.fetch(FetchDescriptor<SavedRepository>())
        } catch {
            return
        }

        let total = repositories.count
        onProgress?(0, total)

        // Build a lookup so the draining loop can find the right model by owner/name.
        let repoMap = Dictionary(
            uniqueKeysWithValues: repositories.map { ("\($0.owner)/\($0.name)", $0) }
        )

        var completed = 0

        await withTaskGroup(of: RepoSyncFetch.self) { group in
            var submitted = 0

            // Seed the initial batch.
            while submitted < Self.maxConcurrentRepos && submitted < total {
                let r = repositories[submitted]
                let owner = r.owner, name = r.name
                group.addTask { await self.fetchAll(owner: owner, name: name) }
                submitted += 1
            }

            // As each repo finishes its fetch, apply the results and submit the next.
            for await result in group {
                completed += 1
                onProgress?(completed, total)

                if let repo = repoMap["\(result.owner)/\(result.name)"] {
                    await applyAll(result, to: repo, in: context)
                }

                if submitted < total {
                    let r = repositories[submitted]
                    let owner = r.owner, name = r.name
                    group.addTask { await self.fetchAll(owner: owner, name: name) }
                    submitted += 1
                }
            }
        }

        try? context.save()
    }

    // MARK: - Private

    /// Fires all six sub-service network fetches for a single repository concurrently.
    ///
    /// This method is `nonisolated` so it can be called directly from `withTaskGroup`
    /// task closures without requiring a main-actor hop. All parameters and return values
    /// are `Sendable`.
    nonisolated private func fetchAll(owner: String, name: String) async -> RepoSyncFetch {
        async let dependabotAlerts = securityService.fetchDependabotAlerts(owner: owner, repo: name)
        async let codeScanningAlerts = securityService.fetchCodeScanningAlerts(owner: owner, repo: name)
        async let secretScanningAlerts = securityService.fetchSecretScanningAlerts(owner: owner, repo: name)
        async let codeownersEntries = codeownersService.fetchEntries(owner: owner, repo: name)
        async let velocityData = velocityService.fetchVelocityData(owner: owner, repo: name)
        async let openPRs = pullRequestService.fetchOpenPRs(owner: owner, repo: name)

        let (dep, cs, ss, co, vel, prs) = await (
            dependabotAlerts, codeScanningAlerts, secretScanningAlerts,
            codeownersEntries, velocityData, openPRs
        )

        return RepoSyncFetch(
            owner: owner, name: name,
            dependabotAlerts: dep, codeScanningAlerts: cs, secretScanningAlerts: ss,
            codeownersEntries: co, velocityData: vel, openPRs: prs
        )
    }

    /// Writes a completed ``RepoSyncFetch`` to SwiftData and updates badge counts.
    ///
    /// Code scanning uses the delta path: open alerts are upserted first, then any alert
    /// that was open in the DB but absent from the incoming list is fetched individually to
    /// capture its resolution state (fixed or dismissed).
    private func applyAll(_ fetch: RepoSyncFetch, to repository: SavedRepository, in context: ModelContext) async {
        securityService.applyDependabotAlerts(fetch.dependabotAlerts, to: repository, in: context)
        await securityService.deltaApplyCodeScanningAlerts(
            openAlerts: fetch.codeScanningAlerts,
            owner: fetch.owner,
            repo: fetch.name,
            to: repository,
            in: context
        )
        securityService.applySecretScanningAlerts(fetch.secretScanningAlerts, to: repository, in: context)
        codeownersService.applyCodeowners(fetch.codeownersEntries, to: repository, in: context)
        velocityService.applyVelocityData(fetch.velocityData, to: repository, in: context)
        pullRequestService.applyOpenPRs(fetch.openPRs, to: repository, in: context)

    }
}

// MARK: - RepoSyncFetch

/// All network-fetched data for a single repository, ready to be applied to SwiftData.
///
/// All stored properties are `Sendable` so this type can cross actor boundaries as the
/// result of a `withTaskGroup` task.
private struct RepoSyncFetch: Sendable {
    let owner: String
    let name: String
    let dependabotAlerts: [DependabotAlertResponse]?
    let codeScanningAlerts: [CodeScanningAlertResponse]?
    let secretScanningAlerts: [SecretScanningAlertResponse]?
    let codeownersEntries: [(pattern: String, handle: String)]
    let velocityData: VelocityFetchResult?
    let openPRs: [OpenPRData]?
}
