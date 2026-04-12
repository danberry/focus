import Foundation

// MARK: - GitHubTeam

/// A GitHub team within an organization.
struct GitHubTeam: Codable, Sendable, Hashable, Identifiable {

    // MARK: - Properties

    /// The unique numeric identifier for the team.
    let id: Int

    /// The display name of the team.
    let name: String

    /// The URL-safe slug used to reference the team in API paths.
    let slug: String

    /// A short description of the team's purpose, or `nil` if none is set.
    let description: String?

    /// The visibility setting of the team (e.g. `"secret"` or `"closed"`), or `nil` if unknown.
    let privacy: String?

    /// The number of members in the team, or `nil` if not included in this response.
    let membersCount: Int?

    /// The number of repositories the team has access to, or `nil` if not included in this response.
    let reposCount: Int?
}
