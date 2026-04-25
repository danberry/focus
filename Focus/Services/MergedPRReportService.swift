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

    /// Computes the median time from PR open to merge (in whole hours) across the provided
    /// repositories for the given date range.
    ///
    /// Returns `nil` when there are no repositories, no merged PRs in the range, or on any error.
    ///
    /// - Parameters:
    ///   - repositories: The repositories to query, each identified by owner and name.
    ///   - startDate: The first calendar day (UTC) of the range, inclusive.
    ///   - endDate: The last calendar day (UTC) of the range, inclusive.
    /// - Returns: The median merge cycle time in hours, or `nil`.
    func fetchMedianMergeHours(
        for repositories: [(owner: String, name: String)],
        from startDate: Date,
        to endDate: Date
    ) async throws -> Int? {
        let byRepo = try await fetchMergedPRs(for: repositories, from: startDate, to: endDate)
        let cycleTimes: [Double] = byRepo.values.flatMap { $0 }.compactMap { pr in
            let hours = pr.mergedAt.timeIntervalSince(pr.createdAt) / 3600
            return hours >= 0 ? hours : nil
        }
        guard !cycleTimes.isEmpty else { return nil }
        let sorted = cycleTimes.sorted()
        let mid = sorted.count / 2
        let median = sorted.count % 2 == 0
            ? (sorted[mid - 1] + sorted[mid]) / 2
            : sorted[mid]
        return Int(median.rounded())
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
                let createdAtStr = node.createdAt,
                let createdAt = iso.date(from: createdAtStr),
                let mergedAtStr = node.mergedAt,
                let mergedAt = iso.date(from: mergedAtStr),
                let url = node.url,
                let repoName = node.repository?.nameWithOwner
            else { continue }

            let firstReviewAt = node.reviews?.nodes.first?.submittedAt.flatMap { iso.date(from: $0) }
            let ciState = node.commits?.nodes.first?.commit.statusCheckRollup?.state

            let pr = MergedPR(
                number: number,
                title: title,
                createdAt: createdAt,
                mergedAt: mergedAt,
                authorLogin: node.author?.login ?? "",
                url: url,
                repoNameWithOwner: repoName,
                additions: node.additions ?? 0,
                deletions: node.deletions ?? 0,
                firstReviewAt: firstReviewAt,
                ciState: ciState
            )
            result[repoName, default: []].append(pr)
        }

        for key in result.keys {
            result[key]?.sort { $0.mergedAt < $1.mergedAt }
        }

        return result
    }

    /// Formats a date as `yyyy-MM-dd` in the device's local timezone for use in GitHub search queries.
    private func formattedDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
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

        /// The ISO 8601 timestamp when this pull request was opened.
        let createdAt: String?

        /// The ISO 8601 timestamp when this pull request was merged, or `nil` if not merged.
        let mergedAt: String?

        /// The author of the pull request, or `nil` if the author account is unavailable.
        let author: Author?

        /// The URL of the pull request on GitHub.
        let url: String?

        /// The repository this pull request belongs to, or `nil` if unavailable.
        let repository: Repo?

        /// The number of lines added by this pull request.
        let additions: Int?

        /// The number of lines deleted by this pull request.
        let deletions: Int?

        /// The first review submitted on this pull request, or `nil` if none.
        let reviews: ReviewConnection?

        /// The last commit on this pull request, used to read CI check results.
        let commits: CommitConnection?

        /// A connection containing the first review submitted on a pull request.
        struct ReviewConnection: Decodable, Sendable {

            /// The review nodes returned by the connection (at most one, per the query's `first: 1`).
            let nodes: [ReviewNode]

            /// A single pull request review node.
            struct ReviewNode: Decodable, Sendable {

                /// The ISO 8601 timestamp when this review was submitted.
                let submittedAt: String?
            }
        }

        /// A connection containing the last commit of a pull request.
        struct CommitConnection: Decodable, Sendable {

            let nodes: [CommitNode]

            struct CommitNode: Decodable, Sendable {

                let commit: Commit

                struct Commit: Decodable, Sendable {

                    let statusCheckRollup: StatusCheckRollup?

                    struct StatusCheckRollup: Decodable, Sendable {
                        /// `"SUCCESS"`, `"FAILURE"`, `"PENDING"`, `"ERROR"`, or `"EXPECTED"`.
                        let state: String
                    }
                }
            }
        }

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
