import Foundation

// MARK: - MergedPRReportService

struct MergedPRReportService: Sendable {
    private let graphQL: GraphQLClient

    init(graphQL: GraphQLClient) {
        self.graphQL = graphQL
    }

    // MARK: - Fetch

    /// Fetches all PRs merged on the given date across the provided repositories.
    /// Returns a dictionary keyed by `owner/name`, with PRs sorted by mergedAt ascending.
    /// Returns an empty dictionary immediately if `repositories` is empty.
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
    /// Returns a dictionary keyed by `owner/name`, with PRs sorted by mergedAt ascending.
    /// Returns an empty dictionary immediately if `repositories` is empty.
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

    private func formattedDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone(identifier: "UTC")
        return fmt.string(from: date)
    }
}

// MARK: - Response Types

private struct SearchResponse: Decodable, Sendable {
    let search: SearchConnection

    struct SearchConnection: Decodable, Sendable {
        let nodes: [SearchNode]
        let pageInfo: PageInfo
    }

    struct PageInfo: Decodable, Sendable {
        let endCursor: String?
        let hasNextPage: Bool
    }

    // All fields are optional: the `... on PullRequest` inline fragment returns
    // nil for non-PR search results (e.g. Issues). The service filters these out.
    struct SearchNode: Decodable, Sendable {
        let number: Int?
        let title: String?
        let mergedAt: String?
        let author: Author?
        let url: String?
        let repository: Repo?

        struct Author: Decodable, Sendable {
            let login: String
        }

        struct Repo: Decodable, Sendable {
            let nameWithOwner: String
        }
    }
}
