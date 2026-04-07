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
    func fetchMergedPRs(for repositories: [SavedRepository], on date: Date) async throws -> [String: [MergedPR]] {
        guard !repositories.isEmpty else { return [:] }

        let dateStr = formattedDate(date)
        let repoQualifiers = repositories
            .map { "repo:\($0.owner)/\($0.name)" }
            .joined(separator: " ")
        let q = "is:pr is:merged merged:\(dateStr) \(repoQualifiers)"

        let variables: [String: any Sendable] = ["q": q]
        let response: SearchResponse = try await graphQL.execute(
            query: ReportQueries.mergedPullRequests,
            variables: variables,
            responseType: SearchResponse.self
        )

        let iso = ISO8601DateFormatter()
        var result: [String: [MergedPR]] = [:]

        for node in response.search.nodes {
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

        // Sort PRs within each repo by mergedAt ascending.
        for key in result.keys {
            result[key]?.sort { $0.mergedAt < $1.mergedAt }
        }

        return result
    }

    // MARK: - Private

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
