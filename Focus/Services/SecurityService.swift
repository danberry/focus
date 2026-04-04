import Foundation

// MARK: - SecurityService

struct SecurityService: Sendable {
    private let rest: RESTClient

    init(rest: RESTClient) {
        self.rest = rest
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
