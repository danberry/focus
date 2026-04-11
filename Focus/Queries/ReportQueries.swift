// MARK: - ReportQueries

enum ReportQueries {
    // Fetches merged pull requests matching a search query.
    // Uses ISSUE search type with a PullRequest inline fragment so PR-specific
    // fields (mergedAt, repository) are returned. Non-PR nodes decode with nil
    // fields and are filtered out by the service layer.
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
                        mergedAt
                        author { login }
                        url
                        repository { nameWithOwner }
                    }
                }
            }
        }
        """
}
