import Foundation
import SwiftData

// MARK: - SecurityService

/// Fetches and persists security alert data for GitHub repositories.
///
/// `SecurityService` operates in two modes:
/// - **Metrics**: count-only fetches for badge display (``fetchMetrics(owner:repo:)``)
/// - **Sync**: full alert fetches that write rich objects to SwiftData
///
/// Each alert type is split into a non-isolated `fetch*` method that returns Sendable
/// data and an `@MainActor apply*` method that writes to SwiftData. The combined
/// `sync*` methods delegate to both and are preserved for direct use (e.g. in tests).
///
/// All network calls go through the injected ``RESTClient``.
struct SecurityService: Sendable {

    // MARK: - Properties

    /// The REST client used for all GitHub API calls.
    private let rest: RESTClient

    // MARK: - Init

    /// Creates a `SecurityService` backed by the given REST client.
    init(rest: RESTClient) {
        self.rest = rest
    }

    // MARK: - Fetch (non-isolated, Sendable results)

    /// Fetches the count of Dependabot alerts dismissed or fixed within a date range.
    ///
    /// Uses `state=dismissed` to enumerate closed alerts, then filters by `dismissed_at`
    /// falling within `[since, until)`. Returns `0` on any network or decoding error.
    ///
    /// - Parameters:
    ///   - owner: The repository owner login.
    ///   - repo: The repository name.
    ///   - since: The start of the date range (inclusive).
    ///   - until: The end of the date range (exclusive).
    /// - Returns: The number of alerts dismissed within the range, or `0` on failure.
    func fetchDismissedAlertCount(owner: String, repo: String, since: Date, until: Date) async -> Int {
        let queryItems = [
            URLQueryItem(name: "state", value: "dismissed"),
            URLQueryItem(name: "per_page", value: "100")
        ]
        let stubs: [DismissedAlertStub]? = try? await rest.getAll(
            path: Endpoint.dependabotAlerts(owner: owner, repo: repo).path,
            queryItems: queryItems
        )
        return stubs?.filter { stub in
            guard let dismissedAt = stub.dismissedAt else { return false }
            return dismissedAt >= since && dismissedAt < until
        }.count ?? 0
    }

    /// Fetches open Dependabot alerts from the GitHub REST API.
    ///
    /// Returns `nil` on any network or decoding error; does not write to SwiftData.
    func fetchDependabotAlerts(owner: String, repo: String) async -> [DependabotAlertResponse]? {
        let queryItems = [
            URLQueryItem(name: "state", value: "open"),
            URLQueryItem(name: "per_page", value: "100")
        ]
        return try? await rest.getAll(
            path: Endpoint.dependabotAlerts(owner: owner, repo: repo).path,
            queryItems: queryItems
        )
    }

    /// Fetches Dependabot alerts of all states (open, dismissed, fixed, auto_dismissed).
    ///
    /// Used on initial repository add to capture the full alert history. Returns `nil` on any
    /// network or decoding error; does not write to SwiftData.
    func fetchAllDependabotAlerts(owner: String, repo: String) async -> [DependabotAlertResponse]? {
        let queryItems = [
            URLQueryItem(name: "state", value: "open,dismissed,fixed,auto_dismissed"),
            URLQueryItem(name: "per_page", value: "100")
        ]
        return try? await rest.getAll(
            path: Endpoint.dependabotAlerts(owner: owner, repo: repo).path,
            queryItems: queryItems
        )
    }

    /// Fetches a single Dependabot alert by its alert number.
    ///
    /// Used during incremental sync to retrieve resolution details for alerts that
    /// have transitioned out of the open state. Returns `nil` on any error.
    func fetchDependabotAlert(owner: String, repo: String, alertNumber: Int) async -> DependabotAlertResponse? {
        return try? await rest.get(
            path: Endpoint.dependabotAlert(owner: owner, repo: repo, alertNumber: alertNumber).path
        )
    }

    /// Fetches open code scanning alerts from the GitHub REST API.
    ///
    /// Returns `nil` on any network or decoding error; does not write to SwiftData.
    func fetchCodeScanningAlerts(owner: String, repo: String) async -> [CodeScanningAlertResponse]? {
        let queryItems = [
            URLQueryItem(name: "state", value: "open"),
            URLQueryItem(name: "per_page", value: "100")
        ]
        return try? await rest.getAll(
            path: Endpoint.codeScanningAlerts(owner: owner, repo: repo).path,
            queryItems: queryItems
        )
    }

    /// Fetches code scanning alerts of all states (open, dismissed, fixed) from the GitHub REST API.
    ///
    /// Used on initial repository add to capture the full alert history. Returns `nil` on any
    /// network or decoding error; does not write to SwiftData.
    func fetchAllCodeScanningAlerts(owner: String, repo: String) async -> [CodeScanningAlertResponse]? {
        let queryItems = [
            URLQueryItem(name: "state", value: "open,dismissed,fixed"),
            URLQueryItem(name: "per_page", value: "100")
        ]
        return try? await rest.getAll(
            path: Endpoint.codeScanningAlerts(owner: owner, repo: repo).path,
            queryItems: queryItems
        )
    }

    /// Fetches a single code scanning alert by its alert number.
    ///
    /// Used during incremental sync to retrieve resolution details for alerts that
    /// have transitioned out of the open state. Returns `nil` on any error.
    func fetchCodeScanningAlert(owner: String, repo: String, alertNumber: Int) async -> CodeScanningAlertResponse? {
        return try? await rest.get(
            path: Endpoint.codeScanningAlert(owner: owner, repo: repo, alertNumber: alertNumber).path
        )
    }

    /// Fetches open secret scanning alerts from the GitHub REST API.
    ///
    /// Returns `nil` on any network or decoding error; does not write to SwiftData.
    func fetchSecretScanningAlerts(owner: String, repo: String) async -> [SecretScanningAlertResponse]? {
        let queryItems = [
            URLQueryItem(name: "state", value: "open"),
            URLQueryItem(name: "per_page", value: "100")
        ]
        return try? await rest.getAll(
            path: Endpoint.secretScanningAlerts(owner: owner, repo: repo).path,
            queryItems: queryItems
        )
    }

    /// Fetches secret scanning alerts of all states (open, resolved).
    ///
    /// Used on initial repository add to capture the full alert history. Returns `nil` on any
    /// network or decoding error; does not write to SwiftData.
    func fetchAllSecretScanningAlerts(owner: String, repo: String) async -> [SecretScanningAlertResponse]? {
        let queryItems = [
            URLQueryItem(name: "state", value: "open,resolved"),
            URLQueryItem(name: "per_page", value: "100")
        ]
        return try? await rest.getAll(
            path: Endpoint.secretScanningAlerts(owner: owner, repo: repo).path,
            queryItems: queryItems
        )
    }

    /// Fetches a single secret scanning alert by its alert number.
    ///
    /// Used during incremental sync to retrieve resolution details for alerts that
    /// have transitioned out of the open state. Returns `nil` on any error.
    func fetchSecretScanningAlert(owner: String, repo: String, alertNumber: Int) async -> SecretScanningAlertResponse? {
        return try? await rest.get(
            path: Endpoint.secretScanningAlert(owner: owner, repo: repo, alertNumber: alertNumber).path
        )
    }

    // MARK: - Apply (@MainActor, writes to SwiftData)

    /// Persists fetched Dependabot alerts to SwiftData using an upsert strategy.
    ///
    /// Existing records are updated in-place (preserving their `PersistentIdentifier`) so views
    /// holding live references are not invalidated. Records absent from `alerts` are left untouched —
    /// resolved alerts persist in the store with their state and resolution timestamps.
    ///
    /// Does nothing when `alerts` is `nil` (preserving any existing data).
    @MainActor
    func applyDependabotAlerts(_ alerts: [DependabotAlertResponse]?, to repository: SavedRepository, in context: ModelContext) {
        guard let alerts else { return }

        var existingByNumber: [Int: DependabotAlert] = [:]
        for alert in repository.dependabotAlertDetails ?? [] {
            if existingByNumber[alert.alertNumber] != nil {
                print("[applyDependabotAlerts] Removing duplicate alert #\(alert.alertNumber)")
                context.delete(alert)
            } else {
                existingByNumber[alert.alertNumber] = alert
            }
        }

        for alert in alerts {
            if let existing = existingByNumber[alert.number] {
                existing.packageName = alert.securityVulnerability.package.name
                existing.severity = alert.securityAdvisory.severity
                existing.fixVersion = alert.securityVulnerability.firstPatchedVersion?.identifier
                existing.createdAt = alert.createdAt
                existing.summary = alert.securityAdvisory.summary
                existing.advisoryDescription = alert.securityAdvisory.description
                existing.ecosystem = alert.securityVulnerability.package.ecosystem
                existing.vulnerableVersionRange = alert.securityVulnerability.vulnerableVersionRange
                existing.ghsaId = alert.securityAdvisory.ghsaId
                existing.cveId = alert.securityAdvisory.cveId
                existing.cvssScore = alert.securityAdvisory.cvss?.score
                existing.htmlUrl = alert.htmlUrl
                existing.manifestPath = alert.dependency.manifestPath
                existing.assignedLogins = alert.assignees.map(\.login)
                existing.state = alert.state
                existing.fixedAt = alert.fixedAt
                existing.dismissedAt = alert.dismissedAt
                existing.dismissedReason = alert.dismissedReason
                existing.autoDismissedAt = alert.autoDismissedAt
            } else {
                let model = DependabotAlert(
                    alertNumber: alert.number,
                    packageName: alert.securityVulnerability.package.name,
                    severity: alert.securityAdvisory.severity,
                    fixVersion: alert.securityVulnerability.firstPatchedVersion?.identifier,
                    createdAt: alert.createdAt,
                    summary: alert.securityAdvisory.summary,
                    advisoryDescription: alert.securityAdvisory.description,
                    ecosystem: alert.securityVulnerability.package.ecosystem,
                    vulnerableVersionRange: alert.securityVulnerability.vulnerableVersionRange,
                    ghsaId: alert.securityAdvisory.ghsaId,
                    cveId: alert.securityAdvisory.cveId,
                    cvssScore: alert.securityAdvisory.cvss?.score,
                    htmlUrl: alert.htmlUrl,
                    manifestPath: alert.dependency.manifestPath,
                    state: alert.state,
                    fixedAt: alert.fixedAt,
                    dismissedAt: alert.dismissedAt,
                    dismissedReason: alert.dismissedReason,
                    autoDismissedAt: alert.autoDismissedAt
                )
                model.assignedLogins = alert.assignees.map(\.login)
                model.repository = repository
                context.insert(model)
                existingByNumber[alert.number] = model
            }
        }
    }

    /// Incrementally syncs Dependabot alerts during a periodic sync.
    ///
    /// Upserts the incoming open alerts, then detects any previously-open alerts that have
    /// dropped off the open list (meaning they were resolved since the last sync). For each
    /// such alert, fetches the individual record from GitHub to capture the final state,
    /// `fixed_at`, `dismissed_at`, and dismissal reason, then persists those details.
    @MainActor
    func deltaApplyDependabotAlerts(
        openAlerts: [DependabotAlertResponse]?,
        owner: String,
        repo: String,
        to repository: SavedRepository,
        in context: ModelContext
    ) async {
        print("[DeltaApply] Pass 1 — applying \(openAlerts?.count ?? 0) open alert(s) for \(owner)/\(repo)")
        applyDependabotAlerts(openAlerts, to: repository, in: context)
        try? context.save()

        guard let openAlerts else {
            print("[DeltaApply] openAlerts is nil, skipping second pass")
            return
        }

        let incomingOpenNumbers = Set(openAlerts.map(\.number))
        let newlyResolvedRecords = (repository.dependabotAlertDetails ?? []).filter {
            $0.state == "open" && !incomingOpenNumbers.contains($0.alertNumber)
        }

        guard !newlyResolvedRecords.isEmpty else {
            print("[DeltaApply] No newly-resolved alerts detected, done")
            return
        }

        print("[DeltaApply] Pass 2 — fetching \(newlyResolvedRecords.count) newly-resolved alert(s)")
        let resolvedResponses: [DependabotAlertResponse] = await withTaskGroup(of: DependabotAlertResponse?.self) { group in
            for record in newlyResolvedRecords {
                let number = record.alertNumber
                group.addTask { await self.fetchDependabotAlert(owner: owner, repo: repo, alertNumber: number) }
            }
            var results: [DependabotAlertResponse] = []
            for await response in group {
                if let r = response { results.append(r) }
            }
            return results
        }

        print("[DeltaApply] Pass 2 — applying \(resolvedResponses.count) resolved alert(s)")
        applyDependabotAlerts(resolvedResponses, to: repository, in: context)

        // For any resolved alert whose individual fetch failed (e.g. withdrawn advisory),
        // mark it auto_dismissed locally so it no longer appears as open.
        let fetchedNumbers = Set(resolvedResponses.map(\.number))
        for record in newlyResolvedRecords where !fetchedNumbers.contains(record.alertNumber) {
            print("[DeltaApply] Alert #\(record.alertNumber) unfetchable — marking auto_dismissed")
            record.state = "auto_dismissed"
            if record.autoDismissedAt == nil { record.autoDismissedAt = Date() }
        }

        try? context.save()
    }

    /// Persists fetched code scanning alerts to SwiftData using an upsert strategy.
    ///
    /// Existing records are updated in-place (preserving their `PersistentIdentifier`) so views
    /// holding live references are not invalidated. Records absent from `alerts` are left untouched —
    /// resolved alerts persist in the store with their state and resolution timestamps.
    ///
    /// Does nothing when `alerts` is `nil` (preserving any existing data).
    @MainActor
    func applyCodeScanningAlerts(_ alerts: [CodeScanningAlertResponse]?, to repository: SavedRepository, in context: ModelContext) {
        guard let alerts else { return }

        var existingByNumber: [Int: CodeScanningAlert] = [:]
        for alert in repository.codeScanningAlertDetails ?? [] {
            if existingByNumber[alert.alertNumber] != nil {
                context.delete(alert)
            } else {
                existingByNumber[alert.alertNumber] = alert
            }
        }

        for response in alerts {
            if let existing = existingByNumber[response.number] {
                existing.ruleName = response.rule.name
                existing.securitySeverityLevel = response.rule.securitySeverityLevel
                existing.createdAt = response.createdAt
                existing.htmlUrl = response.htmlUrl
                existing.ruleId = response.rule.id
                existing.ruleDescription = response.rule.description
                existing.toolName = response.tool?.name
                existing.locationPath = response.mostRecentInstance?.location?.path
                existing.locationStartLine = response.mostRecentInstance?.location?.startLine
                existing.messageText = response.mostRecentInstance?.message?.text
                existing.state = response.state
                existing.fixedAt = response.fixedAt
                existing.dismissedAt = response.dismissedAt
                existing.dismissedReason = response.dismissedReason
                existing.dismissedComment = response.dismissedComment
            } else {
                let alert = CodeScanningAlert(
                    alertNumber: response.number,
                    ruleName: response.rule.name,
                    securitySeverityLevel: response.rule.securitySeverityLevel,
                    createdAt: response.createdAt,
                    htmlUrl: response.htmlUrl,
                    state: response.state,
                    ruleId: response.rule.id,
                    ruleDescription: response.rule.description,
                    toolName: response.tool?.name,
                    locationPath: response.mostRecentInstance?.location?.path,
                    locationStartLine: response.mostRecentInstance?.location?.startLine,
                    messageText: response.mostRecentInstance?.message?.text,
                    fixedAt: response.fixedAt,
                    dismissedAt: response.dismissedAt,
                    dismissedReason: response.dismissedReason,
                    dismissedComment: response.dismissedComment
                )
                alert.repository = repository
                context.insert(alert)
                existingByNumber[response.number] = alert
            }
        }
    }

    /// Incrementally syncs code scanning alerts during a periodic sync.
    ///
    /// Upserts the incoming open alerts, then detects any previously-open alerts that have
    /// dropped off the open list (meaning they were resolved since the last sync). For each
    /// such alert, fetches the individual record from GitHub to capture the final state,
    /// `fixed_at`, `dismissed_at`, and dismissal reason, then persists those details.
    @MainActor
    func deltaApplyCodeScanningAlerts(
        openAlerts: [CodeScanningAlertResponse]?,
        owner: String,
        repo: String,
        to repository: SavedRepository,
        in context: ModelContext
    ) async {
        // Upsert all incoming open alerts.
        applyCodeScanningAlerts(openAlerts, to: repository, in: context)
        try? context.save()

        guard let openAlerts else { return }

        // Find alerts that were open in the DB but absent from the incoming open list.
        let incomingOpenNumbers = Set(openAlerts.map(\.number))
        let newlyResolvedRecords = (repository.codeScanningAlertDetails ?? []).filter {
            $0.state == "open" && !incomingOpenNumbers.contains($0.alertNumber)
        }

        guard !newlyResolvedRecords.isEmpty else { return }

        // Fetch resolution details for each newly resolved alert concurrently.
        let resolvedResponses: [CodeScanningAlertResponse] = await withTaskGroup(of: CodeScanningAlertResponse?.self) { group in
            for record in newlyResolvedRecords {
                let number = record.alertNumber
                group.addTask { await self.fetchCodeScanningAlert(owner: owner, repo: repo, alertNumber: number) }
            }
            var results: [CodeScanningAlertResponse] = []
            for await response in group {
                if let r = response { results.append(r) }
            }
            return results
        }

        // Apply the resolution details (state, fixedAt, dismissedAt, etc.).
        applyCodeScanningAlerts(resolvedResponses, to: repository, in: context)
        try? context.save()
    }

    /// Persists fetched secret scanning alerts to SwiftData using an upsert strategy.
    ///
    /// Existing records are updated in-place (preserving their `PersistentIdentifier`) so views
    /// holding live references are not invalidated. Records absent from `alerts` are left untouched —
    /// resolved alerts persist in the store with their state and resolution timestamp.
    ///
    /// Does nothing when `alerts` is `nil` (preserving any existing data).
    @MainActor
    func applySecretScanningAlerts(_ alerts: [SecretScanningAlertResponse]?, to repository: SavedRepository, in context: ModelContext) {
        guard let alerts else { return }

        var existingByNumber: [Int: SecretScanningAlert] = [:]
        for alert in repository.secretScanningAlertDetails ?? [] {
            if existingByNumber[alert.alertNumber] != nil {
                context.delete(alert)
            } else {
                existingByNumber[alert.alertNumber] = alert
            }
        }

        for response in alerts {
            if let existing = existingByNumber[response.number] {
                existing.secretTypeDisplayName = response.secretTypeDisplayName
                existing.validity = response.validity
                existing.publiclyLeaked = response.publiclyLeaked
                existing.createdAt = response.createdAt
                existing.htmlUrl = response.htmlUrl
                existing.pushProtectionBypassed = response.pushProtectionBypassed ?? false
                existing.multiRepo = response.multiRepo ?? false
                existing.state = response.state
                existing.resolvedAt = response.resolvedAt
                existing.resolution = response.resolution
            } else {
                let alert = SecretScanningAlert(
                    alertNumber: response.number,
                    secretTypeDisplayName: response.secretTypeDisplayName,
                    validity: response.validity,
                    publiclyLeaked: response.publiclyLeaked,
                    createdAt: response.createdAt,
                    htmlUrl: response.htmlUrl,
                    pushProtectionBypassed: response.pushProtectionBypassed ?? false,
                    multiRepo: response.multiRepo ?? false,
                    state: response.state,
                    resolvedAt: response.resolvedAt,
                    resolution: response.resolution
                )
                alert.repository = repository
                context.insert(alert)
                existingByNumber[response.number] = alert
            }
        }
    }

    /// Incrementally syncs secret scanning alerts during a periodic sync.
    ///
    /// Upserts the incoming open alerts, then detects any previously-open alerts that have
    /// dropped off the open list (meaning they were resolved since the last sync). For each
    /// such alert, fetches the individual record from GitHub to capture the final state,
    /// `resolved_at`, and resolution reason, then persists those details.
    @MainActor
    func deltaApplySecretScanningAlerts(
        openAlerts: [SecretScanningAlertResponse]?,
        owner: String,
        repo: String,
        to repository: SavedRepository,
        in context: ModelContext
    ) async {
        applySecretScanningAlerts(openAlerts, to: repository, in: context)
        try? context.save()

        guard let openAlerts else { return }

        let incomingOpenNumbers = Set(openAlerts.map(\.number))
        let newlyResolvedRecords = (repository.secretScanningAlertDetails ?? []).filter {
            $0.state == "open" && !incomingOpenNumbers.contains($0.alertNumber)
        }

        guard !newlyResolvedRecords.isEmpty else { return }

        let resolvedResponses: [SecretScanningAlertResponse] = await withTaskGroup(of: SecretScanningAlertResponse?.self) { group in
            for record in newlyResolvedRecords {
                let number = record.alertNumber
                group.addTask { await self.fetchSecretScanningAlert(owner: owner, repo: repo, alertNumber: number) }
            }
            var results: [SecretScanningAlertResponse] = []
            for await response in group {
                if let r = response { results.append(r) }
            }
            return results
        }

        applySecretScanningAlerts(resolvedResponses, to: repository, in: context)
        try? context.save()
    }

    // MARK: - Sync (fetch + apply, used by tests and legacy call sites)

    /// Fetches the full Dependabot alert history (all states) and persists it to SwiftData.
    ///
    /// Fetches open, dismissed, fixed, and auto-dismissed alerts in a single paginated sweep.
    /// Used when adding a new repository so the complete history is captured immediately.
    /// Returns without writing on any network error.
    @MainActor
    func syncAllDependabotAlerts(owner: String, repo: String, repository: SavedRepository, in context: ModelContext) async {
        let alerts = await fetchAllDependabotAlerts(owner: owner, repo: repo)
        applyDependabotAlerts(alerts, to: repository, in: context)
    }

    /// Fetches open Dependabot alerts and persists them to SwiftData for the given repository.
    ///
    /// Deprecated in favour of ``syncAllDependabotAlerts(owner:repo:repository:in:)`` for initial
    /// adds and ``deltaApplyDependabotAlerts(openAlerts:owner:repo:to:in:)`` (via ``SyncService``)
    /// for periodic syncs. Retained for test use.
    @MainActor
    func syncDependabotAlerts(owner: String, repo: String, repository: SavedRepository, in context: ModelContext) async {
        let alerts = await fetchDependabotAlerts(owner: owner, repo: repo)
        applyDependabotAlerts(alerts, to: repository, in: context)
    }

    /// Fetches the full code scanning alert history (all states) and persists it to SwiftData.
    ///
    /// Fetches open, dismissed, and fixed alerts in a single paginated sweep. Used when adding
    /// a new repository so the complete history is captured immediately. Returns without writing
    /// on any network error.
    @MainActor
    func syncAllCodeScanningAlerts(owner: String, repo: String, repository: SavedRepository, in context: ModelContext) async {
        let alerts = await fetchAllCodeScanningAlerts(owner: owner, repo: repo)
        applyCodeScanningAlerts(alerts, to: repository, in: context)
    }

    /// Fetches open code scanning alerts and persists them to SwiftData for the given repository.
    ///
    /// Deprecated in favour of ``syncAllCodeScanningAlerts(owner:repo:repository:in:)`` for initial
    /// adds and ``deltaApplyCodeScanningAlerts(openAlerts:owner:repo:to:in:)`` (via ``SyncService``)
    /// for periodic syncs. Retained for test use.
    @MainActor
    func syncCodeScanningAlerts(owner: String, repo: String, repository: SavedRepository, in context: ModelContext) async {
        let alerts = await fetchCodeScanningAlerts(owner: owner, repo: repo)
        applyCodeScanningAlerts(alerts, to: repository, in: context)
    }

    /// Fetches the full secret scanning alert history (all states) and persists it to SwiftData.
    ///
    /// Fetches open and resolved alerts in a single paginated sweep. Used when adding
    /// a new repository so the complete history is captured immediately. Returns without writing
    /// on any network error.
    @MainActor
    func syncAllSecretScanningAlerts(owner: String, repo: String, repository: SavedRepository, in context: ModelContext) async {
        let alerts = await fetchAllSecretScanningAlerts(owner: owner, repo: repo)
        applySecretScanningAlerts(alerts, to: repository, in: context)
    }

    /// Fetches open secret scanning alerts and persists them to SwiftData for the given repository.
    ///
    /// Deprecated in favour of ``syncAllSecretScanningAlerts(owner:repo:repository:in:)`` for initial
    /// adds and ``deltaApplySecretScanningAlerts(openAlerts:owner:repo:to:in:)`` (via ``SyncService``)
    /// for periodic syncs. Retained for test use.
    @MainActor
    func syncSecretScanningAlerts(owner: String, repo: String, repository: SavedRepository, in context: ModelContext) async {
        let alerts = await fetchSecretScanningAlerts(owner: owner, repo: repo)
        applySecretScanningAlerts(alerts, to: repository, in: context)
    }

    // MARK: - Update Assignees

    /// Updates the assignee list for a Dependabot alert and returns the resulting logins.
    ///
    /// - Parameters:
    ///   - alertNumber: The GitHub alert number to update.
    ///   - logins: The full set of assignee logins to apply (replaces existing assignees).
    ///   - owner: The repository owner login.
    ///   - repo: The repository name.
    /// - Returns: The updated list of assignee logins as confirmed by the API.
    /// - Throws: Any network or decoding error from the REST client.
    func updateAssignees(
        alertNumber: Int,
        logins: [String],
        owner: String,
        repo: String
    ) async throws -> [String] {
        let body = AssigneesBody(assignees: logins)
        let response: AssigneesResponse = try await rest.patch(
            path: Endpoint.dependabotAlert(owner: owner, repo: repo, alertNumber: alertNumber).path,
            body: body
        )
        return response.assignees.map(\.login)
    }

    // MARK: - Fetch Metrics

    /// Fetches open alert counts for all three security alert types in parallel.
    ///
    /// Count-only — does not persist alert detail to SwiftData.
    /// A 403, 404, or any error for any alert type is treated as `nil` and stored as `0`.
    ///
    /// - Parameters:
    ///   - owner: The repository owner login (user or organization).
    ///   - repo: The repository name.
    /// - Returns: A ``RepositorySecurityMetrics`` with counts for all three alert types.
    func fetchMetrics(owner: String, repo: String) async -> RepositorySecurityMetrics {
        let queryItems = [
            URLQueryItem(name: "state", value: "open"),
            URLQueryItem(name: "per_page", value: "100")
        ]

        async let dependabot: [AlertStub]? = fetchStubs(
            path: Endpoint.dependabotAlerts(owner: owner, repo: repo).path,
            queryItems: queryItems
        )
        async let codeScanning: [AlertStub]? = fetchStubs(
            path: Endpoint.codeScanningAlerts(owner: owner, repo: repo).path,
            queryItems: queryItems
        )
        async let secretScanning: [AlertStub]? = fetchStubs(
            path: Endpoint.secretScanningAlerts(owner: owner, repo: repo).path,
            queryItems: queryItems
        )

        let (d, c, s) = await (dependabot, codeScanning, secretScanning)
        return RepositorySecurityMetrics(
            dependabotAlerts: d?.count,
            codeScanningAlerts: c?.count,
            secretScanningAlerts: s?.count
        )
    }

    // MARK: - Private

    /// Fetches all pages of alert stubs from `path`, returning `nil` on any error.
    private func fetchStubs(path: String, queryItems: [URLQueryItem]) async -> [AlertStub]? {
        do {
            return try await rest.getAll(path: path, queryItems: queryItems)
        } catch {
            return nil
        }
    }
}

// MARK: - AlertStub

/// An intentionally empty decodable type used for counting alert responses.
///
/// Decoding only the array length avoids deserializing the full alert body
/// across potentially hundreds of records.
private struct AlertStub: Decodable, Sendable {}

// MARK: - DismissedAlertStub

/// A minimal decodable type for dismissed Dependabot alert responses.
///
/// Only decodes `dismissed_at` — needed to filter by the week interval.
struct DismissedAlertStub: Decodable, Sendable {

    /// The date and time the alert was dismissed, or `nil` if not yet dismissed.
    let dismissedAt: Date?
}

// MARK: - DependabotAlertResponse

/// A GitHub REST API response for a single Dependabot alert.
struct DependabotAlertResponse: Decodable, Sendable {

    /// The GitHub-assigned alert number.
    let number: Int

    /// The date and time when this alert was created.
    let createdAt: Date

    /// The URL of the alert detail page on GitHub.
    let htmlUrl: String

    /// The current state of the alert: `"open"`, `"dismissed"`, `"fixed"`, or `"auto_dismissed"`.
    let state: String

    /// The date the alert was resolved by a dependency update, or `nil` if not yet fixed.
    let fixedAt: Date?

    /// The date the alert was manually dismissed, or `nil` if not dismissed.
    let dismissedAt: Date?

    /// The reason the alert was dismissed, or `nil` if not dismissed.
    let dismissedReason: String?

    /// The date the alert was automatically dismissed, or `nil` if not auto-dismissed.
    let autoDismissedAt: Date?

    /// The security advisory associated with this alert.
    let securityAdvisory: SecurityAdvisory

    /// The specific vulnerability that triggered this alert.
    let securityVulnerability: SecurityVulnerability

    /// The dependency identified as vulnerable.
    let dependency: Dependency

    /// The GitHub users currently assigned to this alert.
    let assignees: [AssigneeResponse]

    /// A GitHub user assigned to a Dependabot alert.
    struct AssigneeResponse: Decodable, Sendable {
        /// The user's GitHub login handle.
        let login: String
    }

    /// The GitHub Security Advisory associated with a Dependabot alert.
    struct SecurityAdvisory: Decodable, Sendable {
        /// The GitHub Security Advisory identifier.
        let ghsaId: String

        /// The CVE identifier, or `nil` if not assigned.
        let cveId: String?

        /// A short summary of the advisory.
        let summary: String

        /// The full advisory description.
        let description: String

        /// The severity level string (e.g., `"critical"`, `"high"`).
        let severity: String

        /// The CVSS score details, or `nil` if not available.
        let cvss: CVSS?

        /// The CVSS score for a security advisory.
        struct CVSS: Decodable, Sendable {
            /// The numeric CVSS score, or `nil` if not reported.
            let score: Double?
        }
    }

    /// The vulnerability details for a Dependabot alert.
    struct SecurityVulnerability: Decodable, Sendable {
        /// The affected package.
        let package: Package

        /// The first patched version, or `nil` if no fix is available.
        let firstPatchedVersion: FirstPatchedVersion?

        /// The version range string that is vulnerable.
        let vulnerableVersionRange: String

        /// An affected package in a Dependabot security vulnerability.
        struct Package: Decodable, Sendable {
            /// The package ecosystem (e.g., `"npm"`, `"pip"`).
            let ecosystem: String

            /// The package name within its ecosystem.
            let name: String
        }

        /// The first version of a package that resolves a Dependabot vulnerability.
        struct FirstPatchedVersion: Decodable, Sendable {
            /// The version string of the first patched release.
            let identifier: String
        }
    }

    /// The dependency associated with a Dependabot alert.
    struct Dependency: Decodable, Sendable {
        /// The path to the manifest file declaring this dependency, or `nil` if unavailable.
        let manifestPath: String?
    }
}

// MARK: - Assignees Request / Response

/// The request body for updating assignees on a Dependabot alert.
private struct AssigneesBody: Encodable, Sendable {
    /// The complete list of assignee logins to apply (replaces any existing assignees).
    let assignees: [String]
}

/// The GitHub REST API response after updating assignees on a Dependabot alert.
private struct AssigneesResponse: Decodable, Sendable {
    /// The updated list of assigned users.
    let assignees: [AssigneeLogin]

    /// A GitHub user login returned in an assignees response.
    struct AssigneeLogin: Decodable, Sendable {
        /// The user's GitHub login handle.
        let login: String
    }
}

// MARK: - CodeScanningAlertResponse

/// A GitHub REST API response for a single code scanning alert.
struct CodeScanningAlertResponse: Decodable, Sendable {
    /// The GitHub-assigned alert number.
    let number: Int

    /// The date and time when this alert was created.
    let createdAt: Date

    /// The URL of the alert detail page on GitHub.
    let htmlUrl: String

    /// The current state of the alert: `"open"`, `"dismissed"`, or `"fixed"`.
    let state: String

    /// The date and time when the alert was resolved by a code change, or `nil` if not fixed.
    let fixedAt: Date?

    /// The date and time when the alert was manually dismissed, or `nil` if not dismissed.
    let dismissedAt: Date?

    /// The reason the alert was dismissed (e.g. `"false positive"`), or `nil` if not dismissed.
    let dismissedReason: String?

    /// A free-text comment left on dismissal, or `nil` if none was provided.
    let dismissedComment: String?

    /// The code scanning rule that triggered this alert.
    let rule: Rule

    /// The analysis tool that produced this alert, or `nil` if not provided.
    let tool: Tool?

    /// The most recent instance of this alert, or `nil` if not provided.
    let mostRecentInstance: Instance?

    /// A code scanning rule that produced an alert.
    struct Rule: Decodable, Sendable {
        /// The stable identifier for the rule (e.g., `"js/sql-injection"`).
        let id: String?

        /// The human-readable name of the rule.
        let name: String

        /// A short description of what the rule checks for, or `nil` if not provided.
        let description: String?

        /// The security severity level of the rule, or `nil` if not classified.
        let securitySeverityLevel: String?
    }

    /// The analysis tool that generated a code scanning alert.
    struct Tool: Decodable, Sendable {
        /// The name of the tool (e.g., `"CodeQL"`).
        let name: String
    }

    /// A single instance of a code scanning alert in the repository.
    struct Instance: Decodable, Sendable {
        /// The location within the file where the issue was found, or `nil` if not provided.
        let location: Location?

        /// The human-readable message describing the specific finding, or `nil` if not provided.
        let message: Message?

        /// The file location of a code scanning alert instance.
        struct Location: Decodable, Sendable {
            /// The path to the file relative to the repository root.
            let path: String?

            /// The first line of the flagged code region.
            let startLine: Int?
        }

        /// The descriptive message for a code scanning alert instance.
        struct Message: Decodable, Sendable {
            /// The human-readable text of the finding.
            let text: String?
        }
    }
}

// MARK: - SecretScanningAlertResponse

/// A GitHub REST API response for a single secret scanning alert.
struct SecretScanningAlertResponse: Decodable, Sendable {
    /// The GitHub-assigned alert number.
    let number: Int

    /// The human-readable display name for the secret type.
    let secretTypeDisplayName: String

    /// The validity state of the detected secret (e.g., `"active"`, `"revoked"`).
    let validity: String

    /// Whether the secret has been publicly leaked.
    let publiclyLeaked: Bool

    /// The date and time when this alert was created.
    let createdAt: Date

    /// The URL of the alert on GitHub.com.
    let htmlUrl: String

    /// Whether push protection was bypassed to introduce this secret. Nil means not applicable.
    let pushProtectionBypassed: Bool?

    /// Whether this secret has been detected in more than one repository. Nil means not applicable.
    let multiRepo: Bool?

    /// The current state of the alert: `"open"` or `"resolved"`.
    let state: String

    /// The date the alert was resolved, or `nil` if still open.
    let resolvedAt: Date?

    /// The reason the alert was resolved (e.g., `"false_positive"`, `"revoked"`), or `nil` if not resolved.
    let resolution: String?
}
