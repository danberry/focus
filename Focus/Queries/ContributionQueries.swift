// MARK: - ContributionQueries

enum ContributionQueries {
    // Fetches aggregate contribution counts for a user within a given date range.
    // The `from` and `to` variables must be ISO 8601 DateTime strings.
    // Maximum range: 373 days. For a 30-day rolling window, this limit is irrelevant.
    // Note: always pass `to` explicitly — the default for an omitted `to` is `from + 1 year`, not now.
    static let contributions = """
        query($login: String!, $from: DateTime!, $to: DateTime!) {
            user(login: $login) {
                contributionsCollection(from: $from, to: $to) {
                    totalCommitContributions
                    totalPullRequestContributions
                    totalPullRequestReviewContributions
                    totalIssueContributions
                }
            }
        }
        """
}
