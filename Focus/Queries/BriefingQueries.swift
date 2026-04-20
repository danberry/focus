// MARK: - BriefingQueries

/// GraphQL query strings for assembling the weekly Focus Briefing.
///
/// `BriefingQueries` is an enum namespace — it cannot be instantiated.
///
/// Queries in this namespace use the GitHub GraphQL Search API with `issueCount`
/// to return totals without fetching or paginating result nodes.
enum BriefingQueries {

    // MARK: - Properties

    /// Fetches a single merged PR count for one repository and date range.
    ///
    /// The `$q` variable is a GitHub Search query string, for example:
    /// ```
    /// "repo:owner/name is:pr is:merged merged:2026-04-13..2026-04-19"
    /// ```
    ///
    /// - Note: `first: 1` is required by the GitHub Search API even when only
    ///   `issueCount` is needed. The single returned node is never read.
    ///
    /// - Important: GitHub's Search API has a rate limit of 30 requests per minute for
    ///   authenticated requests. Each repository fires one request.
    // TODO: Batch multiple repositories into a single aliased query — the current fan-out wastes up to N search calls per briefing render.
    static let weeklyMergedPRCount = """
        query BriefingWeeklyPRs($q: String!) {
            search(query: $q, type: ISSUE, first: 1) { issueCount }
        }
        """

    /// Fetches merged PRs with their CI check state for one repository and date range.
    ///
    /// The `$q` variable is a GitHub Search query string, for example:
    /// ```
    /// "repo:owner/name is:pr is:merged merged:2026-04-13..2026-04-19"
    /// ```
    ///
    /// Each PR node includes the `statusCheckRollup.state` of its head commit.
    /// PRs whose head commit has no check rollup (`null`) are excluded by the caller
    /// so they do not inflate or deflate the pass rate.
    ///
    /// - Note: `after` is an optional pagination cursor; omit it on the first page.
    static let ciPassRate = """
        query BriefingCIPassRate($q: String!, $after: String) {
            search(query: $q, type: ISSUE, first: 100, after: $after) {
                pageInfo { hasNextPage endCursor }
                nodes {
                    ... on PullRequest {
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

    /// Fetches the 20 most-recently-created releases for one repository.
    ///
    /// The response nodes include `publishedAt` (null for drafts) so the caller can
    /// filter to releases published within a specific window without extra queries.
    static let recentReleases = """
        query BriefingRecentReleases($owner: String!, $name: String!) {
            repository(owner: $owner, name: $name) {
                releases(first: 20, orderBy: {field: CREATED_AT, direction: DESC}) {
                    nodes {
                        publishedAt
                    }
                }
            }
        }
        """
}
