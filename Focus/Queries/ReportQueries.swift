// MARK: - ReportQueries

/// GraphQL queries used by the Reports tab.
enum ReportQueries {

    // MARK: - Properties

    /// Fetches merged pull requests matching a search query.
    ///
    /// Uses the `ISSUE` search type with a `PullRequest` inline fragment so PR-specific
    /// fields (`mergedAt`, `repository`) are returned. Non-PR nodes decode with `nil`
    /// fields and are filtered out by the service layer.
    ///
    /// - Note: GitHub's search API hard-caps pagination at 1000 results; requests beyond
    ///   that limit return an empty page regardless of `$after` cursor.
    // TODO: Handle `author: nil` in the service layer — accounts deleted after merge return a null author node, which currently decodes silently as a nil login and may produce misleading attribution in reports.
    // TODO: Add `labels` and `reviewDecision` fields to the fragment — required before filtered report views (e.g. "awaiting review") can be built without a second network request.
    static let mergedPullRequests = """
        query MergedPRs($q: String!, $first: Int!, $after: String) {
            search(query: $q, type: ISSUE, first: $first, after: $after) {
                pageInfo {
                    endCursor
                    hasNextPage
                }
                nodes {
                    ... on PullRequest {
                        number
                        title
                        createdAt
                        mergedAt
                        author { login }
                        url
                        repository { nameWithOwner }
                        additions
                        deletions
                        reviews(first: 1) {
                            nodes {
                                submittedAt
                            }
                        }
                        commits(last: 1) {
                            nodes {
                                commit {
                                    statusCheckRollup {
                                        state
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        """
}
