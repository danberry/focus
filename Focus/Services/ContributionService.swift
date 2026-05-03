import Foundation
import SwiftData

// MARK: - ContributionService

/// Fetches and persists GitHub contribution data for team members.
///
/// `ContributionService` operates in two modes:
/// - **Global**: fetches contributions across all repositories the member has contributed to.
/// - **Organization-scoped**: fetches contributions scoped to the tracked organizations, issuing
///   one GraphQL query per org and aggregating the results.
///
/// All network calls go through the injected ``GraphQLClient``.
struct ContributionService: Sendable {

    // MARK: - Properties

    /// The GraphQL client used to execute contribution queries.
    private let graphQL: GraphQLClient

    // MARK: - Init

    /// Creates a new `ContributionService`.
    ///
    /// - Parameter graphQL: The client used to execute GitHub GraphQL queries.
    init(graphQL: GraphQLClient) {
        self.graphQL = graphQL
    }

    // MARK: - Sync

    /// Syncs contributions for a single member over the trailing 365 days.
    ///
    /// When `organizationIDs` is non-empty the query is issued once per organization (using each
    /// org's GitHub global node ID) and the results are aggregated. This scopes contributions to
    /// only the repositories owned by the tracked organizations.
    ///
    /// When `organizationIDs` is empty the global query is used, returning contributions across
    /// all repositories the member has contributed to.
    ///
    /// Existing ``MemberContribution`` and ``DailyContribution`` records for the member are
    /// replaced on every successful sync. Errors are silently discarded to preserve existing data.
    ///
    /// - Parameters:
    ///   - login: The member's GitHub login.
    ///   - member: The ``Member`` SwiftData object to update.
    ///   - organizationIDs: GitHub global node IDs of tracked organizations; pass `[]` for the global query.
    ///   - context: The SwiftData model context used for persistence.
    /// Syncs contributions for a single member using an isolated ``ModelContext`` created from
    /// the supplied container. All parameters are `Sendable`, making this overload safe to call
    /// from concurrent `withTaskGroup` child tasks without capturing non-Sendable types.
    nonisolated func syncContributions(
        login: String,
        memberID: PersistentIdentifier,
        organizationIDs: [String] = [],
        in container: ModelContainer
    ) async {
        let context = ModelContext(container)
        let all = (try? context.fetch(FetchDescriptor<Member>())) ?? []
        guard let member = all.first(where: { $0.persistentModelID == memberID }) else { return }

        let now = Date()
        guard let oneYearAgo = Calendar.current.date(byAdding: .day, value: -365, to: now) else { return }

        let formatter = ISO8601DateFormatter()
        let fromString = formatter.string(from: oneYearAgo)
        let toString = formatter.string(from: now)

        do {
            var totalCommits = 0
            var totalPRs = 0
            var totalReviews = 0
            var totalIssues = 0
            var dailyCounts: [String: Int] = [:]

            if organizationIDs.isEmpty {
                let response: ContributionsResponse = try await graphQL.execute(
                    query: ContributionQueries.contributions,
                    variables: ["login": login, "from": fromString, "to": toString],
                    responseType: ContributionsResponse.self
                )
                guard let collection = response.user?.contributionsCollection else { return }
                totalCommits = collection.totalCommitContributions
                totalPRs = collection.totalPullRequestContributions
                totalReviews = collection.totalPullRequestReviewContributions
                totalIssues = collection.totalIssueContributions
                accumulateDailyCounts(from: collection.contributionCalendar, into: &dailyCounts)
            } else {
                var receivedAnyData = false
                for orgID in organizationIDs {
                    let response: ContributionsResponse = try await graphQL.execute(
                        query: ContributionQueries.contributionsInOrganization,
                        variables: ["login": login, "from": fromString, "to": toString, "organizationID": orgID],
                        responseType: ContributionsResponse.self
                    )
                    guard let collection = response.user?.contributionsCollection else { continue }
                    totalCommits += collection.totalCommitContributions
                    totalPRs += collection.totalPullRequestContributions
                    totalReviews += collection.totalPullRequestReviewContributions
                    totalIssues += collection.totalIssueContributions
                    accumulateDailyCounts(from: collection.contributionCalendar, into: &dailyCounts)
                    receivedAnyData = true
                }
                guard receivedAnyData else { return }
            }

            if let existing = member.contributions?.first {
                existing.commits = totalCommits
                existing.pullRequests = totalPRs
                existing.reviews = totalReviews
                existing.issues = totalIssues
                existing.periodStart = oneYearAgo
                existing.periodEnd = now
                existing.fetchedAt = now
                for extra in (member.contributions ?? []).dropFirst() {
                    extra.member = nil
                    context.delete(extra)
                }
            } else {
                let contribution = MemberContribution(
                    commits: totalCommits,
                    pullRequests: totalPRs,
                    reviews: totalReviews,
                    issues: totalIssues,
                    periodStart: oneYearAgo,
                    periodEnd: now,
                    fetchedAt: now
                )
                contribution.member = member
                context.insert(contribution)
            }

            member.contributionCount = totalCommits + totalPRs + totalReviews + totalIssues

            syncDailyContributions(from: dailyCounts, member: member, in: context)

            try? context.save()
        } catch {
            // Silent failure — keeps any existing data intact.
        }
    }

    @MainActor
    func syncContributions(
        login: String,
        member: Member,
        organizationIDs: [String] = [],
        in context: ModelContext
    ) async {
        let now = Date()
        guard let oneYearAgo = Calendar.current.date(byAdding: .day, value: -365, to: now) else { return }

        let formatter = ISO8601DateFormatter()
        let fromString = formatter.string(from: oneYearAgo)
        let toString = formatter.string(from: now)

        do {
            var totalCommits = 0
            var totalPRs = 0
            var totalReviews = 0
            var totalIssues = 0
            // Keyed by date string ("yyyy-MM-dd") so counts from multiple orgs on the same day merge.
            var dailyCounts: [String: Int] = [:]

            if organizationIDs.isEmpty {
                // Global query — contributions across all repositories.
                let response: ContributionsResponse = try await graphQL.execute(
                    query: ContributionQueries.contributions,
                    variables: [
                        "login": login,
                        "from": fromString,
                        "to": toString
                    ],
                    responseType: ContributionsResponse.self
                )
                guard let collection = response.user?.contributionsCollection else { return }
                totalCommits = collection.totalCommitContributions
                totalPRs = collection.totalPullRequestContributions
                totalReviews = collection.totalPullRequestReviewContributions
                totalIssues = collection.totalIssueContributions
                accumulateDailyCounts(from: collection.contributionCalendar, into: &dailyCounts)
            } else {
                // Per-organization queries — one pass per org, aggregate results.
                var receivedAnyData = false
                for orgID in organizationIDs {
                    let response: ContributionsResponse = try await graphQL.execute(
                        query: ContributionQueries.contributionsInOrganization,
                        variables: [
                            "login": login,
                            "from": fromString,
                            "to": toString,
                            "organizationID": orgID
                        ],
                        responseType: ContributionsResponse.self
                    )
                    guard let collection = response.user?.contributionsCollection else { continue }
                    totalCommits += collection.totalCommitContributions
                    totalPRs += collection.totalPullRequestContributions
                    totalReviews += collection.totalPullRequestReviewContributions
                    totalIssues += collection.totalIssueContributions
                    accumulateDailyCounts(from: collection.contributionCalendar, into: &dailyCounts)
                    receivedAnyData = true
                }
                guard receivedAnyData else { return }
            }

            // Upsert: update the existing MemberContribution in-place, or insert if none exists.
            if let existing = member.contributions?.first {
                existing.commits = totalCommits
                existing.pullRequests = totalPRs
                existing.reviews = totalReviews
                existing.issues = totalIssues
                existing.periodStart = oneYearAgo
                existing.periodEnd = now
                existing.fetchedAt = now
                // Delete any extras beyond the first (shouldn't exist, but guard against it)
                for extra in (member.contributions ?? []).dropFirst() {
                    extra.member = nil
                    context.delete(extra)
                }
            } else {
                let contribution = MemberContribution(
                    commits: totalCommits,
                    pullRequests: totalPRs,
                    reviews: totalReviews,
                    issues: totalIssues,
                    periodStart: oneYearAgo,
                    periodEnd: now,
                    fetchedAt: now
                )
                contribution.member = member
                context.insert(contribution)
            }

            member.contributionCount = totalCommits + totalPRs + totalReviews + totalIssues

            syncDailyContributions(from: dailyCounts, member: member, in: context)

            try? context.save()
        } catch {
            // Silent failure — keeps any existing data intact.
        }
    }

    // MARK: - Private

    /// Merges daily contribution counts from a calendar response into a date-keyed accumulator.
    private func accumulateDailyCounts(
        from calendar: ContributionsResponse.ContributionCalendar,
        into dailyCounts: inout [String: Int]
    ) {
        for week in calendar.weeks {
            for day in week.contributionDays {
                dailyCounts[day.date, default: 0] += day.contributionCount
            }
        }
    }

    /// Upserts ``DailyContribution`` records for the member from the given date-keyed counts.
    ///
    /// Existing objects are updated in-place (preserving their `PersistentIdentifier`) so views
    /// holding live references are not invalidated. Stale dates are deleted; new dates are inserted.
    private func syncDailyContributions(
        from dailyCounts: [String: Int],
        member: Member,
        in context: ModelContext
    ) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = .current

        // Snapshot before mutating the relationship
        let snapshot = member.dailyContributions ?? []
        var existingByDate: [String: DailyContribution] = [:]
        for record in snapshot {
            let key = dateFormatter.string(from: record.date)
            existingByDate[key] = record
        }

        // Update existing or delete stale
        for (key, record) in existingByDate {
            if let newCount = dailyCounts[key] {
                record.count = newCount
            } else {
                record.member = nil
                context.delete(record)
            }
        }

        // Insert new dates not already tracked
        for (dateString, count) in dailyCounts where existingByDate[dateString] == nil {
            guard let date = dateFormatter.date(from: dateString) else { continue }
            let record = DailyContribution(date: date, count: count)
            record.member = member
            context.insert(record)
        }
    }
}

// MARK: - API Response Types

/// A GitHub GraphQL API response containing a user's contribution data.
private struct ContributionsResponse: Decodable, Sendable {

    /// The user node returned by the query, or `nil` if the login was not found.
    let user: UserNode?

    /// A GitHub user node containing contribution data.
    struct UserNode: Decodable, Sendable {

        /// The contribution collection for the requested time window.
        let contributionsCollection: Collection

        /// A collection of GitHub contribution counts and calendar data for a time period.
        struct Collection: Decodable, Sendable {

            /// The total number of commit contributions in the period.
            let totalCommitContributions: Int

            /// The total number of pull request contributions in the period.
            let totalPullRequestContributions: Int

            /// The total number of pull request review contributions in the period.
            let totalPullRequestReviewContributions: Int

            /// The total number of issue contributions in the period.
            let totalIssueContributions: Int

            /// The contribution calendar containing per-day counts.
            let contributionCalendar: ContributionCalendar
        }
    }

    /// A calendar of daily contribution counts organized by week.
    struct ContributionCalendar: Decodable, Sendable {

        /// The weeks in this calendar, each containing one or more days.
        let weeks: [Week]

        /// A single week of contribution data.
        struct Week: Decodable, Sendable {

            /// The individual days within this week.
            let contributionDays: [Day]

            /// A single day's contribution record.
            struct Day: Decodable, Sendable {

                /// The date of this contribution day, formatted as `"yyyy-MM-dd"`.
                let date: String

                /// The total number of contributions on this day.
                let contributionCount: Int
            }
        }
    }
}
