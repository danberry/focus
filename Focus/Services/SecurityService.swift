import Foundation
import SwiftData

// MARK: - SecurityService

/// Fetches and persists security alert data for GitHub repositories.
///
/// `SecurityService` operates in two modes:
/// - **Metrics**: count-only fetches for badge display (``fetchMetrics(owner:repo:)``)
/// - **Sync**: full alert fetches that write rich objects to SwiftData
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

    // MARK: - Sync Alert Details

    /// Fetches open Dependabot alerts and persists them to SwiftData for the given repository.
    ///
    /// Performs a full-replace sync: all existing ``DependabotAlert`` records for `repository`
    /// are deleted before new alerts are inserted.
    /// Silently discards errors to preserve any existing data.
    ///
    /// - Parameters:
    ///   - owner: The repository owner login (user or organization).
    ///   - repo: The repository name.
    ///   - repository: The ``SavedRepository`` to associate new alerts with.
    ///   - context: The SwiftData model context to insert and delete alerts in.
    @MainActor
    func syncDependabotAlerts(owner: String, repo: String, repository: SavedRepository, in context: ModelContext) async {
        let queryItems = [
            URLQueryItem(name: "state", value: "open"),
            URLQueryItem(name: "per_page", value: "100")
        ]

        do {
            let alerts: [DependabotAlertResponse] = try await rest.getAll(
                path: Endpoint.dependabotAlerts(owner: owner, repo: repo).path,
                queryItems: queryItems
            )

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
        } catch {
            // Silently fail — keeps any existing data intact
        }
    }

    /// Fetches open code scanning alerts and persists them to SwiftData for the given repository.
    ///
    /// Performs a full-replace sync: all existing ``CodeScanningAlert`` records for `repository`
    /// are deleted before new alerts are inserted. Returns without writing on any network error.
    ///
    /// - Parameters:
    ///   - owner: The repository owner login (user or organization).
    ///   - repo: The repository name.
    ///   - repository: The ``SavedRepository`` to associate new alerts with.
    ///   - context: The SwiftData model context to insert and delete alerts in.
    @MainActor
    func syncCodeScanningAlerts(owner: String, repo: String, repository: SavedRepository, in context: ModelContext) async {
        let queryItems = [
            URLQueryItem(name: "state", value: "open"),
            URLQueryItem(name: "per_page", value: "100")
        ]
        let alerts: [CodeScanningAlertResponse]
        do {
            alerts = try await rest.getAll(
                path: Endpoint.codeScanningAlerts(owner: owner, repo: repo).path,
                queryItems: queryItems
            )
        } catch {
            return
        }

        // Full replace sync: delete existing alerts for this repository.
        // Nil out the inverse relationship first so SwiftData updates the array synchronously.
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
                htmlUrl: response.htmlUrl
            )
            alert.repository = repository
            context.insert(alert)
        }
    }

    /// Fetches open secret scanning alerts and persists them to SwiftData for the given repository.
    ///
    /// Performs a full-replace sync: all existing ``SecretScanningAlert`` records for `repository`
    /// are deleted before new alerts are inserted. Returns without writing on any network error.
    ///
    /// - Parameters:
    ///   - owner: The repository owner login (user or organization).
    ///   - repo: The repository name.
    ///   - repository: The ``SavedRepository`` to associate new alerts with.
    ///   - context: The SwiftData model context to insert and delete alerts in.
    @MainActor
    func syncSecretScanningAlerts(owner: String, repo: String, repository: SavedRepository, in context: ModelContext) async {
        let queryItems = [
            URLQueryItem(name: "state", value: "open"),
            URLQueryItem(name: "per_page", value: "100")
        ]
        let responses: [SecretScanningAlertResponse]
        do {
            responses = try await rest.getAll(
                path: Endpoint.secretScanningAlerts(owner: owner, repo: repo).path,
                queryItems: queryItems
            )
        } catch {
            return
        }

        // Full replace sync: delete existing alerts for this repository.
        // Nil out the inverse relationship first so SwiftData updates the array synchronously.
        let existing = repository.secretScanningAlertDetails
        for alert in existing {
            alert.repository = nil
            context.delete(alert)
        }

        for response in responses {
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

        async let dependabot: [AlertStub]? = fetch(
            path: Endpoint.dependabotAlerts(owner: owner, repo: repo).path,
            queryItems: queryItems
        )
        async let codeScanning: [AlertStub]? = fetch(
            path: Endpoint.codeScanningAlerts(owner: owner, repo: repo).path,
            queryItems: queryItems
        )
        async let secretScanning: [AlertStub]? = fetch(
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

    /// Fetches all pages of alerts from `path`, returning `nil` on any error.
    private func fetch(path: String, queryItems: [URLQueryItem]) async -> [AlertStub]? {
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
private struct DependabotAlertResponse: Decodable, Sendable {

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
private struct CodeScanningAlertResponse: Decodable, Sendable {
    /// The GitHub-assigned alert number.
    let number: Int

    /// The date and time when this alert was created.
    let createdAt: Date

    /// The URL of the alert detail page on GitHub.
    let htmlUrl: String

    /// The code scanning rule that triggered this alert.
    let rule: Rule

    /// A code scanning rule that produced an alert.
    struct Rule: Decodable, Sendable {
        /// The human-readable name of the rule.
        let name: String

        /// The security severity level of the rule, or `nil` if not classified.
        let securitySeverityLevel: String?
    }
}

// MARK: - SecretScanningAlertResponse

/// A GitHub REST API response for a single secret scanning alert.
private struct SecretScanningAlertResponse: Decodable, Sendable {
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
