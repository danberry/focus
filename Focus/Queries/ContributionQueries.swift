// MARK: - ContributionQueries

enum ContributionQueries {
    // Fetches aggregate contribution counts and per-day calendar data for a user within a given date range.
    // The `from` and `to` variables must be ISO 8601 DateTime strings.
    // Maximum range: 373 days. For a 365-day rolling window, this limit is not exceeded.
    // Note: always pass `to` explicitly — the default for an omitted `to` is `from + 1 year`, not now.
    static let contributions = """
        query($login: String!, $from: DateTime!, $to: DateTime!) {
            user(login: $login) {
                contributionsCollection(from: $from, to: $to) {
                    totalCommitContributions
                    totalPullRequestContributions
                    totalPullRequestReviewContributions
                    totalIssueContributions
                    contributionCalendar {
                        weeks {
                            contributionDays {
                                date
                                contributionCount
                            }
                        }
                    }
                }
            }
        }
        """

    // Fetches contributions scoped to a single organization (by its GitHub global node ID).
    // Use this when one or more organizations have been added; call once per organization and aggregate results.
    static let contributionsInOrganization = """
        query($login: String!, $from: DateTime!, $to: DateTime!, $organizationID: ID!) {
            user(login: $login) {
                contributionsCollection(from: $from, to: $to, organizationID: $organizationID) {
                    totalCommitContributions
                    totalPullRequestContributions
                    totalPullRequestReviewContributions
                    totalIssueContributions
                    contributionCalendar {
                        weeks {
                            contributionDays {
                                date
                                contributionCount
                            }
                        }
                    }
                }
            }
        }
        """
}
