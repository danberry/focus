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
        // Implemented in Task 1
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
        // Implemented in Task 3
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
