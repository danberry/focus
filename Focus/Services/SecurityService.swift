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

    // MARK: - Apply (@MainActor, writes to SwiftData)

    /// Persists fetched Dependabot alerts to SwiftData, replacing any existing records.
    ///
    /// Does nothing when `alerts` is `nil` (preserving any existing data).
    @MainActor
    func applyDependabotAlerts(_ alerts: [DependabotAlertResponse]?, to repository: SavedRepository, in context: ModelContext) {
        guard let alerts else { return }

        repository.dependabotAlertDetails.forEach { context.delete($0) }

        for alert in alerts {
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
                manifestPath: alert.dependency.manifestPath
            )
            model.assignedLogins = alert.assignees.map(\.login)
            model.repository = repository
            context.insert(model)
        }
        try? context.save()
    }

    /// Persists fetched code scanning alerts to SwiftData, replacing any existing records.
    ///
    /// Does nothing when `alerts` is `nil` (preserving any existing data).
    @MainActor
    func applyCodeScanningAlerts(_ alerts: [CodeScanningAlertResponse]?, to repository: SavedRepository, in context: ModelContext) {
        guard let alerts else { return }

        let toDelete = repository.codeScanningAlertDetails
        for existing in toDelete {
            existing.repository = nil
            context.delete(existing)
        }

        for response in alerts {
            let alert = CodeScanningAlert(
                alertNumber: response.number,
                ruleName: response.rule.name,
                securitySeverityLevel: response.rule.securitySeverityLevel,
                createdAt: response.createdAt,
                htmlUrl: response.htmlUrl,
                ruleId: response.rule.id,
                ruleDescription: response.rule.description,
                toolName: response.tool?.name,
                locationPath: response.mostRecentInstance?.location?.path,
                locationStartLine: response.mostRecentInstance?.location?.startLine,
                messageText: response.mostRecentInstance?.message?.text
            )
            alert.repository = repository
            context.insert(alert)
        }
    }

    /// Persists fetched secret scanning alerts to SwiftData, replacing any existing records.
    ///
    /// Does nothing when `alerts` is `nil` (preserving any existing data).
    @MainActor
    func applySecretScanningAlerts(_ alerts: [SecretScanningAlertResponse]?, to repository: SavedRepository, in context: ModelContext) {
        guard let alerts else { return }

        let existing = repository.secretScanningAlertDetails
        for alert in existing {
            alert.repository = nil
            context.delete(alert)
        }

        for response in alerts {
            let alert = SecretScanningAlert(
                alertNumber: response.number,
                secretTypeDisplayName: response.secretTypeDisplayName,
                validity: response.validity,
                publiclyLeaked: response.publiclyLeaked,
                createdAt: response.createdAt,
                htmlUrl: response.htmlUrl,
                pushProtectionBypassed: response.pushProtectionBypassed ?? false,
                multiRepo: response.multiRepo ?? false
            )
            alert.repository = repository
            context.insert(alert)
        }
    }

    // MARK: - Sync (fetch + apply, used by tests and legacy call sites)

    /// Fetches open Dependabot alerts and persists them to SwiftData for the given repository.
    ///
    /// Performs a full-replace sync: all existing ``DependabotAlert`` records for `repository`
    /// are deleted before new alerts are inserted.
    /// Silently discards errors to preserve any existing data.
    @MainActor
    func syncDependabotAlerts(owner: String, repo: String, repository: SavedRepository, in context: ModelContext) async {
        let alerts = await fetchDependabotAlerts(owner: owner, repo: repo)
        applyDependabotAlerts(alerts, to: repository, in: context)
    }

    /// Fetches open code scanning alerts and persists them to SwiftData for the given repository.
    ///
    /// Performs a full-replace sync: all existing ``CodeScanningAlert`` records for `repository`
    /// are deleted before new alerts are inserted. Returns without writing on any network error.
    @MainActor
    func syncCodeScanningAlerts(owner: String, repo: String, repository: SavedRepository, in context: ModelContext) async {
        let alerts = await fetchCodeScanningAlerts(owner: owner, repo: repo)
        applyCodeScanningAlerts(alerts, to: repository, in: context)
    }

    /// Fetches open secret scanning alerts and persists them to SwiftData for the given repository.
    ///
    /// Performs a full-replace sync: all existing ``SecretScanningAlert`` records for `repository`
    /// are deleted before new alerts are inserted. Returns without writing on any network error.
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

// MARK: - DependabotAlertResponse

/// A GitHub REST API response for a single Dependabot alert.
struct DependabotAlertResponse: Decodable, Sendable {

    /// The GitHub-assigned alert number.
    let number: Int

    /// The date and time when this alert was created.
    let createdAt: Date

    /// The URL of the alert detail page on GitHub.
    let htmlUrl: String

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
}
