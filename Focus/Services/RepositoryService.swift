import Foundation

// MARK: - RepositoryService

/// Fetches GitHub repository data via the GraphQL API.
///
/// `RepositoryService` supports three operations:
/// - **Viewer repositories**: paginated list of the authenticated user's repositories
/// - **Single repository**: fetch a specific repository by owner and name
/// - **Search**: paginated repository search by query string
///
/// All network calls go through the injected ``GraphQLClient``.
struct RepositoryService: Sendable {

    // MARK: - Properties

    /// The GraphQL client used to execute repository queries.
    private let graphQL: GraphQLClient

    // MARK: - Init

    /// Creates a new repository service.
    ///
    /// - Parameter graphQL: The GraphQL client to use for all network requests.
    init(graphQL: GraphQLClient) {
        self.graphQL = graphQL
    }

    // MARK: - Fetch Viewer Repositories

    /// Fetches a paginated list of repositories owned by the authenticated user.
    ///
    /// - Parameters:
    ///   - first: The maximum number of repositories to return. Defaults to `20`.
    ///   - after: An opaque cursor for pagination; pass the `endCursor` from a previous response to fetch the next page.
    /// - Returns: A tuple containing the repositories, an optional end cursor for the next page, and a flag indicating whether more pages exist.
    /// - Throws: Any network or decoding error encountered during the request.
    func fetchViewerRepositories(
        first: Int = 20,
        after: String? = nil
    ) async throws -> (repos: [GitHubRepository], endCursor: String?, hasNextPage: Bool) {
        var variables: [String: any Sendable] = ["first": first]
        if let after { variables["after"] = after }

        let response: ViewerReposResponse = try await graphQL.execute(
            query: RepositoryQueries.viewerRepositories,
            variables: variables,
            responseType: ViewerReposResponse.self
        )
        let repos = response.viewer.repositories.nodes
        let pageInfo = response.viewer.repositories.pageInfo
        return (repos, pageInfo.endCursor, pageInfo.hasNextPage)
    }

    // MARK: - Fetch Repository

    /// Fetches a single repository by owner login and repository name.
    ///
    /// - Parameters:
    ///   - owner: The repository owner login (user or organization).
    ///   - name: The repository name.
    /// - Returns: The matching ``GitHubRepository``.
    /// - Throws: Any network or decoding error encountered during the request.
    func fetchRepository(owner: String, name: String) async throws -> GitHubRepository {
        let response: RepoResponse = try await graphQL.execute(
            query: RepositoryQueries.repository,
            variables: ["owner": owner, "name": name],
            responseType: RepoResponse.self
        )
        return response.repository
    }

    // MARK: - Search Repositories

    /// Searches GitHub repositories using a query string, returning a paginated result.
    ///
    /// - Parameters:
    ///   - query: The GitHub search query string (e.g., `"language:Swift stars:>100"`).
    ///   - first: The maximum number of results to return. Defaults to `20`.
    ///   - after: An opaque cursor for pagination; pass the `endCursor` from a previous response to fetch the next page.
    /// - Returns: A tuple containing the matching repositories, an optional end cursor for the next page, and a flag indicating whether more pages exist.
    /// - Throws: Any network or decoding error encountered during the request.
    func searchRepositories(
        query: String,
        first: Int = 20,
        after: String? = nil
    ) async throws -> (repos: [GitHubRepository], endCursor: String?, hasNextPage: Bool) {
        var variables: [String: any Sendable] = ["query": query, "first": first]
        if let after { variables["after"] = after }

        let response: SearchResponse = try await graphQL.execute(
            query: RepositoryQueries.searchRepositories,
            variables: variables,
            responseType: SearchResponse.self
        )
        let repos = response.search.edges.map(\.node)
        return (repos, response.search.pageInfo.endCursor, response.search.pageInfo.hasNextPage)
    }
}

// MARK: - API Response Types

/// The top-level GraphQL response for the viewer's repositories query.
private struct ViewerReposResponse: Decodable, Sendable {

    /// The authenticated viewer and their repositories.
    let viewer: ViewerRepos

    /// A wrapper for the viewer's paginated repository connection.
    struct ViewerRepos: Decodable, Sendable {

        /// The paginated list of repositories.
        let repositories: RepositoryConnection
    }

    /// A paginated collection of repositories with cursor metadata.
    struct RepositoryConnection: Decodable, Sendable {

        /// The repositories returned for this page.
        let nodes: [GitHubRepository]

        /// Pagination metadata for this result set.
        let pageInfo: PageInfo
    }
}

/// The top-level GraphQL response for a single repository lookup.
private struct RepoResponse: Decodable, Sendable {

    /// The repository matching the requested owner and name.
    let repository: GitHubRepository
}

/// The top-level GraphQL response for a repository search query.
private struct SearchResponse: Decodable, Sendable {

    /// The search result containing matching repository edges.
    let search: SearchResult

    /// A paginated search result containing repository edges.
    struct SearchResult: Decodable, Sendable {

        /// The edges wrapping each matched repository.
        let edges: [Edge]

        /// Pagination metadata for this search result.
        let pageInfo: PageInfo
    }

    /// A search result edge wrapping a single repository.
    struct Edge: Decodable, Sendable {

        /// The repository matched by this edge.
        let node: GitHubRepository
    }
}

/// Pagination cursor metadata returned by GitHub's GraphQL connection pattern.
private struct PageInfo: Decodable, Sendable {

    /// An opaque cursor pointing to the last item in this page, or `nil` if there are no results.
    let endCursor: String?

    /// Whether another page of results exists after this one.
    let hasNextPage: Bool
}
