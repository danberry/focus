import Foundation
import SwiftData

// MARK: - PullRequestService

/// Fetches and persists open pull request data for GitHub repositories.
///
/// `PullRequestService` performs a full-replace sync, removing all existing
/// open PR records for a repository before inserting fresh results from the
/// GitHub GraphQL API. Silent failures leave any previously persisted data intact.
///
/// All network calls go through the injected ``GraphQLClient``.
struct PullRequestService: Sendable {

    // MARK: - Properties

    /// The GraphQL client used to execute pull request queries.
    private let graphQL: GraphQLClient

    // MARK: - Init

    /// Creates a pull request service backed by the given GraphQL client.
    init(graphQL: GraphQLClient) {
        self.graphQL = graphQL
    }

    // MARK: - Sync

    /// Fetches open pull requests for a repository and replaces any existing records in SwiftData.
    ///
    /// Performs a full-replace sync: all existing open PR records for `repository` are deleted
    /// before the fresh results are inserted. Errors from the network or SwiftData are silently
    /// discarded, leaving any previously persisted data intact.
    ///
    /// - Parameters:
    ///   - owner: The repository owner login (user or organization).
    ///   - repo: The repository name.
    ///   - repository: The `SavedRepository` record whose open PRs will be replaced.
    ///   - context: The SwiftData model context used for persistence.
    @MainActor
    func syncOpenPullRequests(owner: String, repo: String, repository: SavedRepository, in context: ModelContext) async {
        let variables: [String: any Sendable] = [
            "owner": owner,
            "name": repo
        ]

        do {
            let response: PRResponse = try await graphQL.execute(
                query: RepositoryQueries.openPullRequests,
                variables: variables,
                responseType: PRResponse.self
            )

            // Full-replace sync: remove existing open PR records for this repository.
            for existing in repository.openPullRequests {
                existing.repository = nil
                context.delete(existing)
            }

            let iso = ISO8601DateFormatter()

            for node in response.repository.pullRequests.nodes {
                let createdAt = iso.date(from: node.createdAt) ?? Date()
                let pr = OpenPullRequest(
                    number: node.number,
                    title: node.title,
                    createdAt: createdAt,
                    authorLogin: node.author?.login ?? "",
                    url: node.url
                )
                pr.repository = repository
                context.insert(pr)
            }

            try? context.save()
        } catch {
            // Silently fail — keeps any existing data intact
        }
    }
}

// MARK: - API Response Types

/// The top-level GraphQL response for an open pull requests query.
private struct PRResponse: Decodable, Sendable {

    /// The repository returned by the query.
    let repository: PRRepository

    /// A repository node containing its pull request connection.
    struct PRRepository: Decodable, Sendable {

        /// The paginated connection of pull requests for this repository.
        let pullRequests: PRConnection
    }

    /// A GraphQL connection containing a list of pull request nodes.
    struct PRConnection: Decodable, Sendable {

        /// The pull request nodes returned by this connection.
        let nodes: [PRNode]
    }

    /// A single pull request node from the GraphQL response.
    struct PRNode: Decodable, Sendable {

        /// The pull request number within the repository.
        let number: Int

        /// The pull request title.
        let title: String

        /// The ISO 8601 creation timestamp for the pull request.
        let createdAt: String

        /// The author of the pull request, or `nil` if the author has been deleted.
        let author: PRAuthor?

        /// The URL of the pull request on GitHub.
        let url: String
    }

    /// The author of a pull request.
    struct PRAuthor: Decodable, Sendable {

        /// The GitHub login for this author.
        let login: String
    }
}
