// MARK: - VelocityQueries

/// GraphQL query strings for fetching merged pull request velocity metrics.
///
/// `VelocityQueries` is an enum namespace — it cannot be instantiated.
///
/// All queries in this namespace use the GitHub GraphQL Search API with field aliases to
/// batch multiple counts into a single round-trip. Each alias maps to one `(period, type)`
/// pair — current window and prior-year window — for each of the four velocity periods:
/// 7-day, 30-day, 90-day, and year-to-date.
///
/// The 8-alias batching strategy avoids making separate network requests per period
/// by issuing one query with 8 aliased `search` fields. Each field uses `issueCount`
/// to return a total match count without fetching or paginating result nodes.
enum VelocityQueries {

    // MARK: - Properties

    /// Fetches merged PR counts for all four velocity periods in a single GraphQL request.
    ///
    /// Issues one query with 8 aliased `search` fields — one for the current window and
    /// one for the prior-year window of each period (7-day, 30-day, 90-day, year-to-date).
    /// `issueCount` returns the total match count without requiring pagination.
    ///
    /// Each variable is a GitHub Search query string, for example:
    /// ```
    /// "repo:owner/name is:pr is:merged merged:2025-01-01..2025-04-06"
    /// ```
    ///
    /// Aliases returned:
    /// - `w7Current` / `w7Prior` — 7-day window, current vs. prior year
    /// - `d30Current` / `d30Prior` — 30-day window, current vs. prior year
    /// - `d90Current` / `d90Prior` — 90-day window, current vs. prior year
    /// - `ytdCurrent` / `ytdPrior` — year-to-date window, current vs. prior year
    ///
    /// - Note: `first: 1` is required by the GitHub Search API even when only `issueCount`
    ///   is needed. The single returned node is never read.
    ///
    /// - Important: GitHub's Search API has a rate limit of 30 requests per minute for
    ///   authenticated requests. Each call to this query counts as one request.
    // TODO: Replace `first: 1` with `first: 0` if GitHub ever allows zero-node searches — currently `first: 0` is rejected by the API, forcing a wasted node fetch per alias.
    // TODO: Add a `@skip` directive per alias so callers can request only the periods they need — reduces unnecessary search calls when a view only shows one period.
    static let mergedPRCounts = """
        query PRVelocity(
            $q7c: String!, $q7p: String!,
            $q30c: String!, $q30p: String!,
            $q90c: String!, $q90p: String!,
            $qYc: String!, $qYp: String!
        ) {
            w7Current:  search(query: $q7c,  type: ISSUE, first: 1) { issueCount }
            w7Prior:    search(query: $q7p,  type: ISSUE, first: 1) { issueCount }
            d30Current: search(query: $q30c, type: ISSUE, first: 1) { issueCount }
            d30Prior:   search(query: $q30p, type: ISSUE, first: 1) { issueCount }
            d90Current: search(query: $q90c, type: ISSUE, first: 1) { issueCount }
            d90Prior:   search(query: $q90p, type: ISSUE, first: 1) { issueCount }
            ytdCurrent: search(query: $qYc,  type: ISSUE, first: 1) { issueCount }
            ytdPrior:   search(query: $qYp,  type: ISSUE, first: 1) { issueCount }
        }
        """
}
