import Foundation

// MARK: - GitHubRepository

/// A GitHub repository returned by the API.
struct GitHubRepository: Codable, Sendable, Hashable, Identifiable {

    // MARK: - Properties

    /// The repository's unique GitHub node ID.
    let id: String

    /// The short name of the repository.
    let name: String

    /// The full repository name including owner login (e.g., `"owner/repo"`), or `nil` if absent.
    let nameWithOwner: String?

    /// A human-readable description of the repository, or `nil` if none is set.
    let description: String?

    /// The visibility of the repository (`"PUBLIC"`, `"PRIVATE"`, or `"INTERNAL"`).
    let visibility: String

    /// Whether the repository is a fork of another repository.
    let isFork: Bool

    /// The number of users who have starred the repository.
    let stargazerCount: Int

    /// The number of times the repository has been forked.
    let forkCount: Int

    /// The repository's primary programming language, or `nil` if GitHub reports none.
    let primaryLanguage: Language?

    /// The URL of the repository on GitHub.
    let url: String

    /// The ISO 8601 timestamp of the most recent update, or `nil` if unavailable.
    let updatedAt: String?

    /// The repository owner, or `nil` if absent from the API response.
    let owner: Owner?

    // MARK: - Nested Types

    /// A programming language associated with a repository.
    struct Language: Codable, Sendable, Hashable {

        /// The display name of the language.
        let name: String
    }

    /// The owner of a GitHub repository.
    struct Owner: Codable, Sendable, Hashable {

        /// The owner's GitHub login (username or organization name).
        let login: String

        /// The URL of the owner's avatar image, or `nil` if unavailable.
        let avatarUrl: String?
    }
}
