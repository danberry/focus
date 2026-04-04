import Foundation

// MARK: - RepositoryService

struct RepositoryService: Sendable {
    private let graphQL: GraphQLClient

    init(graphQL: GraphQLClient) {
        self.graphQL = graphQL
    }

    // MARK: - Fetch Viewer Repositories

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

    func fetchRepository(owner: String, name: String) async throws -> GitHubRepository {
        let response: RepoResponse = try await graphQL.execute(
            query: RepositoryQueries.repository,
            variables: ["owner": owner, "name": name],
            responseType: RepoResponse.self
        )
        return response.repository
    }

    // MARK: - Search Repositories

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

// MARK: - Response Types

private struct ViewerReposResponse: Decodable, Sendable {
    let viewer: ViewerRepos

    struct ViewerRepos: Decodable, Sendable {
        let repositories: RepositoryConnection
    }

    struct RepositoryConnection: Decodable, Sendable {
        let nodes: [GitHubRepository]
        let pageInfo: PageInfo
    }
}

private struct RepoResponse: Decodable, Sendable {
    let repository: GitHubRepository
}

private struct SearchResponse: Decodable, Sendable {
    let search: SearchResult

    struct SearchResult: Decodable, Sendable {
        let edges: [Edge]
        let pageInfo: PageInfo
    }

    struct Edge: Decodable, Sendable {
        let node: GitHubRepository
    }
}

private struct PageInfo: Decodable, Sendable {
    let endCursor: String?
    let hasNextPage: Bool
}
