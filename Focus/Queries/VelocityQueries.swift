// MARK: - VelocityQueries

enum VelocityQueries {
    // Fetches merged PR counts for 4 period types (current + prior year) in a single request.
    // Uses GraphQL Search with aliases so all 8 counts are returned in one round-trip.
    // issueCount returns the total match count without requiring pagination.
    // Each variable is a GitHub search query string, e.g.
    //   "repo:owner/name is:pr is:merged merged:2025-01-01..2025-04-06"
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
