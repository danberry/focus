import Foundation
import SwiftData

// MARK: - SyncService

/// Orchestrates a full data sync for every saved repository.
///
/// `SyncService` sequences calls to ``SecurityService``, ``CodeownersService``,
/// ``VelocityService``, and ``PullRequestService``, then derives badge counts
/// from the freshly written SwiftData relationships.
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

    /// Syncs all saved repositories sequentially, then saves the model context.
    ///
    /// A failure to fetch the repository list is silently discarded and the
    /// method returns without syncing. Individual sub-service errors are handled
    /// within each service.
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

        for (index, repo) in repositories.enumerated() {
            await sync(repo, in: context)
            onProgress?(index + 1, total)
        }

        try? context.save()
    }

    // MARK: - Private

    /// Syncs security alerts, codeowners, velocity, and open pull requests for a single repository.
    ///
    /// After all sub-service syncs complete, derives badge counts from the freshly written
    /// SwiftData relationship arrays.
    ///
    /// - Parameters:
    ///   - repository: The saved repository to sync.
    ///   - context: The SwiftData model context for persistence.
    private func sync(_ repository: SavedRepository, in context: ModelContext) async {
        let owner = repository.owner
        let name = repository.name

        await securityService.syncDependabotAlerts(owner: owner, repo: name, repository: repository, in: context)
        await securityService.syncCodeScanningAlerts(owner: owner, repo: name, repository: repository, in: context)
        await securityService.syncSecretScanningAlerts(owner: owner, repo: name, repository: repository, in: context)
        await codeownersService.syncCodeowners(owner: owner, repo: name, repository: repository, in: context)
        await velocityService.syncVelocity(owner: owner, repo: name, repository: repository, in: context)
        await pullRequestService.syncOpenPullRequests(owner: owner, repo: name, repository: repository, in: context)

        // Derive badge counts from the freshly synced relationship arrays.
        repository.dependabotAlerts = repository.dependabotAlertDetails.count
        repository.codeScanningAlerts = repository.codeScanningAlertDetails.count
        repository.secretScanningAlerts = repository.secretScanningAlertDetails.count
    }
}
