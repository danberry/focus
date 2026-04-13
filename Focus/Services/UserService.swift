import Foundation

// MARK: - UserService

/// Fetches GitHub user data via the GraphQL API.
///
/// `UserService` operates in two modes:
/// - **Fetch**: point lookups by viewer session or login (`fetchViewer()`, `fetchUser(login:)`)
/// - **Search**: paginated user search queries (`searchUsers(query:first:after:)`)
///
/// All network calls go through the injected ``GraphQLClient``.
struct UserService: Sendable {

    // MARK: - Properties

    /// The GraphQL client used to execute user queries.
    private let graphQL: GraphQLClient

    // MARK: - Init

    /// Creates a `UserService` backed by the given GraphQL client.
    ///
    /// - Parameter graphQL: The client used to send all GraphQL requests.
    init(graphQL: GraphQLClient) {
        self.graphQL = graphQL
    }

    // MARK: - Fetch

    /// Fetches the profile of the currently authenticated GitHub user.
    ///
    /// - Returns: The authenticated user's ``GitHubUser`` profile.
    /// - Throws: A ``GitHubError`` if the request fails or the token is invalid.
    func fetchViewer() async throws -> GitHubUser {
        let response: ViewerResponse = try await graphQL.execute(
            query: UserQueries.viewer,
            responseType: ViewerResponse.self
        )
        return response.viewer.toUser()
    }

    /// Fetches the GitHub profile for a specific user login.
    ///
    /// - Parameter login: The GitHub username to look up.
    /// - Returns: The matching user's ``GitHubUser`` profile.
    /// - Throws: A ``GitHubError`` if the user is not found or the request fails.
    func fetchUser(login: String) async throws -> GitHubUser {
        let response: UserResponse = try await graphQL.execute(
            query: UserQueries.user,
            variables: ["login": login],
            responseType: UserResponse.self
        )
        return response.user.toUser()
    }

    // MARK: - Search

    /// Searches for GitHub users matching a query string, with optional cursor-based pagination.
    ///
    /// - Parameters:
    ///   - query: The search string forwarded to GitHub's user search API.
    ///   - first: The maximum number of results to return per page; defaults to `20`.
    ///   - after: An opaque cursor from a previous response used to fetch the next page; pass `nil` for the first page.
    /// - Returns: A tuple containing the matched users, the end cursor for the next page (or `nil` if none), and whether another page exists.
    /// - Throws: A ``GitHubError`` if the request fails.
    func searchUsers(
        query: String,
        first: Int = 20,
        after: String? = nil
    ) async throws -> (users: [GitHubUser], endCursor: String?, hasNextPage: Bool) {
        var variables: [String: any Sendable] = ["query": query, "first": first]
        if let after { variables["after"] = after }

        let response: SearchResponse = try await graphQL.execute(
            query: UserQueries.searchUsers,
            variables: variables,
            responseType: SearchResponse.self
        )
        let users = response.search.edges.map { $0.node.toUser() }
        return (users, response.search.pageInfo.endCursor, response.search.pageInfo.hasNextPage)
    }
}

// MARK: - API Response Types

/// A GitHub GraphQL API response wrapping the authenticated viewer's profile.
private struct ViewerResponse: Decodable, Sendable {
    /// The authenticated user's profile data.
    let viewer: GraphQLUser
}

/// A GitHub GraphQL API response wrapping a single user's profile.
private struct UserResponse: Decodable, Sendable {
    /// The requested user's profile data.
    let user: GraphQLUser
}

/// A GitHub GraphQL API response wrapping paginated user search results.
private struct SearchResponse: Decodable, Sendable {

    /// The paginated search result container.
    let search: SearchResult

    /// A paginated list of user search results.
    struct SearchResult: Decodable, Sendable {
        /// The individual result nodes, each wrapping a user profile.
        let edges: [Edge]
        /// Pagination metadata for the current result page.
        let pageInfo: PageInfo
    }

    /// A single edge in a paginated user search result.
    struct Edge: Decodable, Sendable {
        /// The user at this position in the search results.
        let node: GraphQLUser
    }
}

/// Pagination metadata returned by a GitHub GraphQL connection.
private struct PageInfo: Decodable, Sendable {
    /// An opaque cursor pointing to the last item on this page, or `nil` if the result set is empty.
    let endCursor: String?
    /// Whether an additional page of results exists after this one.
    let hasNextPage: Bool
}

/// A GitHub user as returned by the GraphQL API, before mapping to the domain model.
private struct GraphQLUser: Decodable, Sendable {
    /// The stable GitHub node ID for the user.
    let id: String
    /// The user's GitHub username.
    let login: String
    /// The user's display name, or `nil` if not set.
    let name: String?
    /// The URL string for the user's avatar image, or `nil` if not available.
    let avatarUrl: String?
    /// The user's profile bio, or `nil` if not set.
    let bio: String?
    /// The user's listed company, or `nil` if not set.
    let company: String?
    /// The user's listed location, or `nil` if not set.
    let location: String?
    /// The user's public email address, or `nil` if not set or hidden.
    let email: String?
    /// The user's public repository count, wrapped in a GraphQL count object.
    let publicRepos: CountWrapper?
    /// The number of users following this account, wrapped in a GraphQL count object.
    let followers: CountWrapper?
    /// The number of accounts this user follows, wrapped in a GraphQL count object.
    let following: CountWrapper?

    /// A GraphQL wrapper that exposes a connection's item count.
    struct CountWrapper: Decodable, Sendable {
        /// The total number of items in the connection.
        let totalCount: Int
    }

    /// Maps this GraphQL response object to the domain ``GitHubUser`` model.
    func toUser() -> GitHubUser {
        GitHubUser(
            id: id,
            login: login,
            name: name,
            avatarUrl: avatarUrl,
            bio: bio,
            company: company,
            location: location,
            email: email,
            publicRepos: publicRepos?.totalCount,
            followers: followers?.totalCount,
            following: following?.totalCount
        )
    }
}
