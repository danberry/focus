import Foundation

// MARK: - TeamService

struct TeamService: Sendable {
    private let rest: RESTClient

    init(rest: RESTClient) {
        self.rest = rest
    }

    // MARK: - Fetch Teams

    func fetchTeams(organization: String) async throws -> [GitHubTeam] {
        try await rest.get(path: Endpoint.teams(org: organization).path)
    }

    // MARK: - Fetch Team Members

    func fetchTeamMembers(
        organization: String,
        teamSlug: String
    ) async throws -> [RESTUser] {
        try await rest.get(path: Endpoint.teamMembers(org: organization, teamSlug: teamSlug).path)
    }

    // MARK: - Fetch Team Repositories

    func fetchTeamRepositories(
        organization: String,
        teamSlug: String
    ) async throws -> [RESTRepository] {
        try await rest.get(path: Endpoint.teamRepos(org: organization, teamSlug: teamSlug).path)
    }
}

// MARK: - REST Response Models

/// Lightweight user model matching GitHub REST API shape.
struct RESTUser: Codable, Sendable, Hashable, Identifiable {
    let id: Int
    let login: String
    let avatarUrl: String?
    let type: String?
}

/// Lightweight repository model matching GitHub REST API shape.
struct RESTRepository: Codable, Sendable, Hashable, Identifiable {
    let id: Int
    let name: String
    let fullName: String
    let description: String?
    let isPrivate: Bool?
    let fork: Bool?
    let stargazersCount: Int?
    let forksCount: Int?
    let language: String?
    let htmlUrl: String?

    private enum CodingKeys: String, CodingKey {
        case id, name, fullName, description
        case isPrivate = "private"
        case fork, stargazersCount, forksCount, language, htmlUrl
    }
}
