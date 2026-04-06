import Foundation
import SwiftData

// MARK: - SecurityService

struct SecurityService: Sendable {
    private let rest: RESTClient

    init(rest: RESTClient) {
        self.rest = rest
    }

    // MARK: - Sync Alert Details

    @MainActor
    func syncDependabotAlerts(owner: String, repo: String, repository: SavedRepository, in context: ModelContext) async {
        let queryItems = [
            URLQueryItem(name: "state", value: "open"),
            URLQueryItem(name: "per_page", value: "100")
        ]

        do {
            let alerts: [DependabotAlertResponse] = try await rest.get(
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

    @MainActor
    func syncCodeScanningAlerts(owner: String, repo: String, repository: SavedRepository, in context: ModelContext) async {
        let queryItems = [
            URLQueryItem(name: "state", value: "open"),
            URLQueryItem(name: "per_page", value: "100")
        ]
        let alerts: [CodeScanningAlertResponse]
        do {
            alerts = try await rest.get(
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
                createdAt: response.createdAt
            )
            alert.repository = repository
            context.insert(alert)
        }
    }

    @MainActor
    func syncSecretScanningAlerts(owner: String, repo: String, repository: SavedRepository, in context: ModelContext) async {
        let queryItems = [
            URLQueryItem(name: "state", value: "open"),
            URLQueryItem(name: "per_page", value: "100")
        ]
        let responses: [SecretScanningAlertResponse]
        do {
            responses = try await rest.get(
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
                createdAt: response.createdAt
            )
            alert.repository = repository
            context.insert(alert)
        }
    }

    // MARK: - Update Assignees

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

    private func fetch(path: String, queryItems: [URLQueryItem]) async -> [AlertStub]? {
        do {
            return try await rest.get(path: path, queryItems: queryItems)
        } catch {
            return nil
        }
    }
}

// MARK: - AlertStub

private struct AlertStub: Decodable, Sendable {}

// MARK: - DependabotAlertResponse

private struct DependabotAlertResponse: Decodable, Sendable {
    let number: Int
    let createdAt: Date
    let htmlUrl: String
    let securityAdvisory: SecurityAdvisory
    let securityVulnerability: SecurityVulnerability
    let dependency: Dependency
    let assignees: [AssigneeResponse]

    struct AssigneeResponse: Decodable, Sendable {
        let login: String
    }

    struct SecurityAdvisory: Decodable, Sendable {
        let ghsaId: String
        let cveId: String?
        let summary: String
        let description: String
        let severity: String
        let cvss: CVSS?

        struct CVSS: Decodable, Sendable {
            let score: Double?
        }
    }

    struct SecurityVulnerability: Decodable, Sendable {
        let package: Package
        let firstPatchedVersion: FirstPatchedVersion?
        let vulnerableVersionRange: String

        struct Package: Decodable, Sendable {
            let ecosystem: String
            let name: String
        }

        struct FirstPatchedVersion: Decodable, Sendable {
            let identifier: String
        }
    }

    struct Dependency: Decodable, Sendable {
        let manifestPath: String?
    }
}

// MARK: - Assignees Request / Response

private struct AssigneesBody: Encodable, Sendable {
    let assignees: [String]
}

private struct AssigneesResponse: Decodable, Sendable {
    let assignees: [AssigneeLogin]

    struct AssigneeLogin: Decodable, Sendable {
        let login: String
    }
}

// MARK: - CodeScanningAlertResponse

struct CodeScanningAlertResponse: Decodable, Sendable {
    let number: Int
    let createdAt: Date
    let rule: Rule

    struct Rule: Decodable, Sendable {
        let name: String
        let securitySeverityLevel: String?
    }
}

// MARK: - SecretScanningAlertResponse

private struct SecretScanningAlertResponse: Decodable, Sendable {
    let number: Int
    let secretTypeDisplayName: String
    let validity: String
    let publiclyLeaked: Bool
    let createdAt: Date
}
