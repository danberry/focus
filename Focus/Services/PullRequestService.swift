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

    // MARK: - Fetch (non-isolated, Sendable result)

    /// Fetches open pull requests for a repository from the GitHub GraphQL API.
    ///
    /// Returns `nil` on any network or decoding error; does not write to SwiftData.
    func fetchOpenPRs(owner: String, repo: String) async -> [OpenPRData]? {
        let variables: [String: any Sendable] = ["owner": owner, "name": repo]
        do {
            let response: PRResponse = try await graphQL.execute(
                query: RepositoryQueries.openPullRequests,
                variables: variables,
                responseType: PRResponse.self
            )
            return response.repository.pullRequests.nodes.map { node in
                OpenPRData(
                    number: node.number,
                    title: node.title,
                    createdAt: node.createdAt,
                    authorLogin: node.author?.login,
                    url: node.url
                )
            }
        } catch {
            return nil
        }
    }

    // MARK: - Apply (@MainActor, writes to SwiftData)

    /// Persists fetched pull requests to SwiftData, replacing any existing records.
    ///
    /// Does nothing when `prs` is `nil` (preserving any existing data).
    @MainActor
    func applyOpenPRs(_ prs: [OpenPRData]?, to repository: SavedRepository, in context: ModelContext) {
        guard let prs else { return }

        for existing in repository.openPullRequests {
            existing.repository = nil
            context.delete(existing)
        }

        let iso = ISO8601DateFormatter()
        for data in prs {
            let createdAt = iso.date(from: data.createdAt) ?? Date()
            let pr = OpenPullRequest(
                number: data.number,
                title: data.title,
                createdAt: createdAt,
                authorLogin: data.authorLogin ?? "",
                url: data.url
            )
            pr.repository = repository
            context.insert(pr)
        }

        try? context.save()
    }

    // MARK: - Sync (fetch + apply, used by tests and legacy call sites)

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
        let prs = await fetchOpenPRs(owner: owner, repo: repo)
        applyOpenPRs(prs, to: repository, in: context)
    }
}

// MARK: - OpenPRData

/// Sendable transfer type carrying the fields needed to create an ``OpenPullRequest`` SwiftData record.
struct OpenPRData: Sendable {
    let number: Int
    let title: String
    /// ISO 8601 creation timestamp string, parsed to `Date` during apply.
    let createdAt: String
    let authorLogin: String?
    let url: String
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
