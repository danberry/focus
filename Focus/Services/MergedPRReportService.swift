import Foundation

// MARK: - MergedPRReportService

/// Fetches merged pull request data across repositories using the GitHub GraphQL API.
///
/// `MergedPRReportService` supports two query modes:
/// - **Single date**: fetches all PRs merged on a specific calendar day
/// - **Date range**: fetches all PRs merged within an inclusive date range
///
/// Results are keyed by `owner/name` and sorted by merge time ascending.
/// Pagination is handled automatically using GraphQL cursor-based paging.
/// All network calls go through the injected ``GraphQLClient``.
struct MergedPRReportService: Sendable {

    // MARK: - Properties

    /// The GraphQL client used to query the GitHub API.
    private let graphQL: GraphQLClient

    // MARK: - Init

    /// Creates a new service with the given GraphQL client.
    ///
    /// - Parameter graphQL: The client used to execute GitHub GraphQL queries.
    init(graphQL: GraphQLClient) {
        self.graphQL = graphQL
    }

    // MARK: - Fetch

    /// Fetches all PRs merged on the given date across the provided repositories.
    ///
    /// Returns an empty dictionary immediately if `repositories` is empty.
    ///
    /// - Parameters:
    ///   - repositories: The repositories to query, each identified by owner and name.
    ///   - date: The calendar day (UTC) for which to fetch merged PRs.
    /// - Returns: A dictionary keyed by `owner/name`, with PRs sorted by mergedAt ascending.
    /// - Throws: Any GraphQL or network error encountered during fetching.
    func fetchMergedPRs(for repositories: [(owner: String, name: String)], on date: Date) async throws -> [String: [MergedPR]] {
        guard !repositories.isEmpty else { return [:] }

        let dateStr = formattedDate(date)
        let repoQualifiers = repositories
            .map { "repo:\($0.owner)/\($0.name)" }
            .joined(separator: " ")
        let q = "is:pr is:merged merged:\(dateStr) \(repoQualifiers)"

        let nodes = try await fetchAllNodes(q: q)
        return collectPRs(from: nodes)
    }

    /// Fetches all PRs merged within the given date range (inclusive) across the provided repositories.
    ///
    /// Returns an empty dictionary immediately if `repositories` is empty.
    ///
    /// - Parameters:
    ///   - repositories: The repositories to query, each identified by owner and name.
    ///   - startDate: The first calendar day (UTC) of the range, inclusive.
    ///   - endDate: The last calendar day (UTC) of the range, inclusive.
    /// - Returns: A dictionary keyed by `owner/name`, with PRs sorted by mergedAt ascending.
    /// - Throws: Any GraphQL or network error encountered during fetching.
    func fetchMergedPRs(for repositories: [(owner: String, name: String)], from startDate: Date, to endDate: Date) async throws -> [String: [MergedPR]] {
        guard !repositories.isEmpty else { return [:] }

        let startStr = formattedDate(startDate)
        let endStr = formattedDate(endDate)
        let repoQualifiers = repositories
            .map { "repo:\($0.owner)/\($0.name)" }
            .joined(separator: " ")
        let q = "is:pr is:merged merged:\(startStr)..\(endStr) \(repoQualifiers)"

        let nodes = try await fetchAllNodes(q: q)
        return collectPRs(from: nodes)
    }

    // MARK: - Private

    /// Pages through all results for the given search query, returning every node.
    ///
    /// - Parameter q: A GitHub search query string.
    /// - Returns: All search result nodes across all pages.
    /// - Throws: Any GraphQL or network error encountered during fetching.
    private func fetchAllNodes(q: String) async throws -> [SearchResponse.SearchNode] {
        var allNodes: [SearchResponse.SearchNode] = []
        var after: String? = nil
        var hasNextPage = true

        while hasNextPage {
            var variables: [String: any Sendable] = ["q": q, "first": 100]
            if let after { variables["after"] = after }

            let response: SearchResponse = try await graphQL.execute(
                query: ReportQueries.mergedPullRequests,
                variables: variables,
                responseType: SearchResponse.self
            )

            allNodes.append(contentsOf: response.search.nodes)
            after = response.search.pageInfo.endCursor
            hasNextPage = response.search.pageInfo.hasNextPage
        }

        return allNodes
    }

    /// Converts raw search nodes into a dictionary keyed by repo, sorted by mergedAt ascending.
    private func collectPRs(from nodes: [SearchResponse.SearchNode]) -> [String: [MergedPR]] {
        let iso = ISO8601DateFormatter()
        var result: [String: [MergedPR]] = [:]

        for node in nodes {
            guard
                let number = node.number,
                let title = node.title,
                let mergedAtStr = node.mergedAt,
                let mergedAt = iso.date(from: mergedAtStr),
                let url = node.url,
                let repoName = node.repository?.nameWithOwner
            else { continue }

            let pr = MergedPR(
                number: number,
                title: title,
                mergedAt: mergedAt,
                authorLogin: node.author?.login ?? "",
                url: url,
                repoNameWithOwner: repoName
            )
            result[repoName, default: []].append(pr)
        }

        for key in result.keys {
            result[key]?.sort { $0.mergedAt < $1.mergedAt }
        }

        return result
    }

    /// Formats a date as `yyyy-MM-dd` in UTC for use in GitHub search queries.
    private func formattedDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone(identifier: "UTC")
        return fmt.string(from: date)
    }
}

// MARK: - API Response Types

/// A GitHub GraphQL search response containing pull request nodes.
private struct SearchResponse: Decodable, Sendable {

    /// The search connection containing result nodes and pagination info.
    let search: SearchConnection

    /// A paginated collection of search result nodes.
    struct SearchConnection: Decodable, Sendable {

        /// The search result nodes for the current page.
        let nodes: [SearchNode]

        /// Pagination metadata for the current page.
        let pageInfo: PageInfo
    }

    /// Cursor-based pagination metadata for a search result page.
    struct PageInfo: Decodable, Sendable {

        /// The cursor for the last result on the current page, used to fetch the next page.
        let endCursor: String?

        /// Whether additional pages of results are available.
        let hasNextPage: Bool
    }

    /// A single search result node, representing a potential pull request.
    ///
    /// All fields are optional: the `... on PullRequest` inline fragment returns
    /// `nil` for non-PR search results (e.g. Issues). The service filters these out.
    struct SearchNode: Decodable, Sendable {

        /// The pull request number within its repository.
        let number: Int?

        /// The pull request title.
        let title: String?

        /// The ISO 8601 timestamp when this pull request was merged, or `nil` if not merged.
        let mergedAt: String?

        /// The author of the pull request, or `nil` if the author account is unavailable.
        let author: Author?

        /// The URL of the pull request on GitHub.
        let url: String?

        /// The repository this pull request belongs to, or `nil` if unavailable.
        let repository: Repo?

        /// The GitHub user who authored a pull request.
        struct Author: Decodable, Sendable {

            /// The GitHub login of the pull request author.
            let login: String
        }

        /// A repository reference within a search result node.
        struct Repo: Decodable, Sendable {

            /// The repository's full name in `owner/name` format.
            let nameWithOwner: String
        }
    }
}
