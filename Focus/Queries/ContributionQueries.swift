// MARK: - ContributionQueries

/// GraphQL query strings for fetching GitHub contribution data.
///
/// `ContributionQueries` provides two query variants:
/// - **Global**: ``contributions`` fetches all contributions regardless of organization.
/// - **Org-scoped**: ``contributionsInOrganization`` filters contributions to a single organization
///   by its GitHub global node ID.
///
/// When one or more organizations are configured, prefer the org-scoped variant and aggregate
/// results across organizations at the call site.
enum ContributionQueries {

    // MARK: - Properties

    // TODO: Add `restrictedContributionsCount` to both queries — without it, private contributions are silently excluded from all totals when the token lacks `read:user` scope.

    /// Fetches aggregate contribution counts and per-day calendar data for a user within a date range.
    ///
    /// Use this variant when no organization filter is required. Results include contributions
    /// across every organization the user belongs to.
    ///
    /// **Variables**
    /// - `login`: The GitHub username.
    /// - `from`: ISO 8601 DateTime string for the start of the range (inclusive).
    /// - `to`: ISO 8601 DateTime string for the end of the range (inclusive).
    ///
    /// - Note: The maximum supported range is 373 days. Always pass `to` explicitly — omitting it
    ///   defaults to `from + 1 year`, not the current date.
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

    /// Fetches aggregate contribution counts and per-day calendar data scoped to a single organization.
    ///
    /// Use this variant when one or more organizations are configured. The GitHub API does not
    /// support multi-org filtering in a single query, so callers must invoke this once per
    /// organization and aggregate results.
    ///
    /// **Variables**
    /// - `login`: The GitHub username.
    /// - `from`: ISO 8601 DateTime string for the start of the range (inclusive).
    /// - `to`: ISO 8601 DateTime string for the end of the range (inclusive).
    /// - `organizationID`: The GitHub global node ID for the organization (e.g. `MDEyOk...`).
    ///
    /// - Note: The maximum supported range is 373 days. Always pass `to` explicitly — omitting it
    ///   defaults to `from + 1 year`, not the current date.
    // TODO: Aggregation across many organizations is O(n) serial calls — introduce concurrent fetching in the service layer when org counts grow beyond a handful.
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
