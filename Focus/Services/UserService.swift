import Foundation

// MARK: - UserService

struct UserService: Sendable {
    private let graphQL: GraphQLClient

    init(graphQL: GraphQLClient) {
        self.graphQL = graphQL
    }

    // MARK: - Fetch Viewer

    func fetchViewer() async throws -> GitHubUser {
        let response: ViewerResponse = try await graphQL.execute(
            query: UserQueries.viewer,
            responseType: ViewerResponse.self
        )
        return response.viewer.toUser()
    }

    // MARK: - Fetch User

    func fetchUser(login: String) async throws -> GitHubUser {
        let response: UserResponse = try await graphQL.execute(
            query: UserQueries.user,
            variables: ["login": login],
            responseType: UserResponse.self
        )
        return response.user.toUser()
    }

    // MARK: - Search Users

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

// MARK: - Response Types

private struct ViewerResponse: Decodable, Sendable {
    let viewer: GraphQLUser
}

private struct UserResponse: Decodable, Sendable {
    let user: GraphQLUser
}

private struct SearchResponse: Decodable, Sendable {
    let search: SearchResult

    struct SearchResult: Decodable, Sendable {
        let edges: [Edge]
        let pageInfo: PageInfo
    }

    struct Edge: Decodable, Sendable {
        let node: GraphQLUser
    }
}

private struct PageInfo: Decodable, Sendable {
    let endCursor: String?
    let hasNextPage: Bool
}

private struct GraphQLUser: Decodable, Sendable {
    let id: String
    let login: String
    let name: String?
    let avatarUrl: String?
    let bio: String?
    let company: String?
    let location: String?
    let email: String?
    let publicRepos: CountWrapper?
    let followers: CountWrapper?
    let following: CountWrapper?

    struct CountWrapper: Decodable, Sendable {
        let totalCount: Int
    }

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
