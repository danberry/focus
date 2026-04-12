import Foundation

// MARK: - GitHubUser

/// A GitHub user profile decoded from the GitHub API.
///
/// Used for both the authenticated user and members returned as part of team or
/// organization queries. All fields beyond `id` and `login` are optional because
/// GitHub users are not required to populate them.
struct GitHubUser: Codable, Sendable, Hashable, Identifiable {

    // MARK: - Properties

    /// The user's stable GitHub node ID.
    let id: String

    /// The user's login handle (e.g., `"danberry"`).
    let login: String

    /// The user's display name, or `nil` if the user has not set one.
    let name: String?

    /// The URL string for the user's avatar image, or `nil` if unavailable.
    let avatarUrl: String?

    /// The user's profile bio, or `nil` if the user has not set one.
    let bio: String?

    /// The user's company field, or `nil` if the user has not set one.
    let company: String?

    /// The user's stated location, or `nil` if the user has not set one.
    let location: String?

    /// The user's public email address, or `nil` if the user has not made one public.
    let email: String?

    /// The number of public repositories owned by the user, or `nil` if the API did not return it.
    let publicRepos: Int?

    /// The number of accounts following this user, or `nil` if the API did not return it.
    let followers: Int?

    /// The number of accounts this user is following, or `nil` if the API did not return it.
    let following: Int?
}
