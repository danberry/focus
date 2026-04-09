import Foundation

// MARK: - OrganizationService

struct OrganizationService: Sendable {
    private let rest: RESTClient

    init(rest: RESTClient) {
        self.rest = rest
    }

    // MARK: - Fetch Organization

    func fetchOrganization(login: String) async throws -> GitHubOrganization {
        try await rest.get(path: Endpoint.organization(login: login).path)
    }
}
