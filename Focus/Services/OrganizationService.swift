import Foundation

// MARK: - OrganizationService

/// Fetches GitHub organization data from the REST API.
///
/// `OrganizationService` provides a single fetch operation that retrieves
/// the public profile for a GitHub organization by its login handle.
///
/// All network calls go through the injected ``RESTClient``.
struct OrganizationService: Sendable {

    // MARK: - Properties

    /// The REST client used to execute GitHub API requests.
    private let rest: RESTClient

    // MARK: - Init

    /// Creates a new organization service.
    ///
    /// - Parameter rest: The REST client to use for all network requests.
    init(rest: RESTClient) {
        self.rest = rest
    }

    // MARK: - Organizations

    /// Fetches the public profile for a GitHub organization.
    ///
    /// - Parameter login: The organization's login handle (e.g., `"apple"`).
    /// - Returns: A ``GitHubOrganization`` with the organization's profile data.
    /// - Throws: A ``GitHubError`` if the organization is not found or the request fails.
    func fetchOrganization(login: String) async throws -> GitHubOrganization {
        try await rest.get(path: Endpoint.organization(login: login).path)
    }
}
