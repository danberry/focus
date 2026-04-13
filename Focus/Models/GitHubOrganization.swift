import Foundation

// MARK: - GitHubOrganization

/// A GitHub organization returned from the GitHub API.
struct GitHubOrganization: Codable, Sendable, Hashable, Identifiable {

    // MARK: - Properties

    /// The stable GitHub node ID for this organization.
    let id: String

    /// The organization's login handle.
    let login: String

    /// The organization's display name, or `nil` if not set.
    let name: String?

    /// The URL string for the organization's avatar image, or `nil` if not available.
    let avatarUrl: String?

    /// The organization's profile description, or `nil` if not set.
    let description: String?

    // MARK: - Private

    /// Maps JSON response keys to Swift property names.
    enum CodingKeys: String, CodingKey {
        case id = "nodeId"
        case login
        case name
        case avatarUrl
        case description
    }
}
