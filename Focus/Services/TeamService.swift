import Foundation

// MARK: - TeamService

/// Fetches GitHub team data for an organization.
///
/// `TeamService` fetches teams, their members, and their repositories using
/// the GitHub REST API via the injected ``RESTClient``.
struct TeamService: Sendable {

    // MARK: - Properties

    /// The REST client used for all GitHub API requests.
    private let rest: RESTClient

    // MARK: - Init

    /// Creates a new team service.
    ///
    /// - Parameter rest: The REST client to use for network requests.
    init(rest: RESTClient) {
        self.rest = rest
    }

    // MARK: - Fetch

    /// Fetches all teams for the given organization.
    ///
    /// - Parameter organization: The organization login name.
    /// - Returns: An array of ``GitHubTeam`` values.
    /// - Throws: Any network or decoding error encountered during the request.
    func fetchTeams(organization: String) async throws -> [GitHubTeam] {
        try await rest.get(path: Endpoint.teams(org: organization).path)
    }

    /// Fetches all members of a team within an organization.
    ///
    /// - Parameters:
    ///   - organization: The organization login name.
    ///   - teamSlug: The team's URL-safe slug identifier.
    /// - Returns: An array of ``RESTUser`` values representing team members.
    /// - Throws: Any network or decoding error encountered during the request.
    func fetchTeamMembers(
        organization: String,
        teamSlug: String
    ) async throws -> [RESTUser] {
        try await rest.get(path: Endpoint.teamMembers(org: organization, teamSlug: teamSlug).path)
    }

    /// Fetches all repositories accessible to a team within an organization.
    ///
    /// - Parameters:
    ///   - organization: The organization login name.
    ///   - teamSlug: The team's URL-safe slug identifier.
    /// - Returns: An array of ``RESTRepository`` values.
    /// - Throws: Any network or decoding error encountered during the request.
    func fetchTeamRepositories(
        organization: String,
        teamSlug: String
    ) async throws -> [RESTRepository] {
        try await rest.get(path: Endpoint.teamRepos(org: organization, teamSlug: teamSlug).path)
    }
}

// MARK: - REST Response Types

/// A lightweight user model returned by the GitHub REST API.
struct RESTUser: Codable, Sendable, Hashable, Identifiable {

    /// The user's unique GitHub numeric identifier.
    let id: Int

    /// The user's GitHub login name.
    let login: String

    /// The URL of the user's avatar image, or `nil` if unavailable.
    let avatarUrl: String?

    /// The account type (e.g., `"User"` or `"Bot"`).
    let type: String?
}

/// A lightweight repository model returned by the GitHub REST API.
struct RESTRepository: Codable, Sendable, Hashable, Identifiable {

    /// The repository's unique GitHub numeric identifier.
    let id: Int

    /// The short name of the repository.
    let name: String

    /// The full name of the repository in `owner/repo` format.
    let fullName: String

    /// A user-provided description of the repository, or `nil` if none is set.
    let description: String?

    /// Whether the repository is private.
    let isPrivate: Bool?

    /// Whether the repository is a fork.
    let fork: Bool?

    /// The number of users who have starred the repository.
    let stargazersCount: Int?

    /// The number of forks of the repository.
    let forksCount: Int?

    /// The primary programming language used in the repository, or `nil` if GitHub reports none.
    let language: String?

    /// The URL of the repository's GitHub web page.
    let htmlUrl: String?

    // MARK: - Private

    /// Maps Swift property names to their GitHub REST API JSON keys.
    private enum CodingKeys: String, CodingKey {
        case id, name, fullName, description
        case isPrivate = "private"
        case fork, stargazersCount, forksCount, language, htmlUrl
    }
}
