import Foundation
import SwiftData

// MARK: - SyncService

/// Orchestrates a full sync of security alerts and codeowners for every saved repository.
@MainActor
struct SyncService: Sendable {
    private let securityService: SecurityService
    private let codeownersService: CodeownersService

    init(securityService: SecurityService, codeownersService: CodeownersService) {
        self.securityService = securityService
        self.codeownersService = codeownersService
    }

    // MARK: - Sync All

    /// Syncs every saved repository in turn, then persists the results.
    func syncAll(in context: ModelContext) async {
        let repositories: [SavedRepository]
        do {
            repositories = try context.fetch(FetchDescriptor<SavedRepository>())
        } catch {
            return
        }

        for repo in repositories {
            await sync(repo, in: context)
        }

        try? context.save()
    }

    // MARK: - Private

    /// Syncs all three security alert types and codeowners for a single repository,
    /// then updates the badge counts from the synced relationship arrays.
    private func sync(_ repository: SavedRepository, in context: ModelContext) async {
        let owner = repository.owner
        let name = repository.name

        await securityService.syncDependabotAlerts(owner: owner, repo: name, repository: repository, in: context)
        await securityService.syncCodeScanningAlerts(owner: owner, repo: name, repository: repository, in: context)
        await securityService.syncSecretScanningAlerts(owner: owner, repo: name, repository: repository, in: context)
        await codeownersService.syncCodeowners(owner: owner, repo: name, repository: repository, in: context)

        // Derive badge counts from the freshly synced relationship arrays.
        repository.dependabotAlerts = repository.dependabotAlertDetails.count
        repository.codeScanningAlerts = repository.codeScanningAlertDetails.count
        repository.secretScanningAlerts = repository.secretScanningAlertDetails.count
    }
}
