import Foundation
import SwiftData

// MARK: - ContributionService

struct ContributionService: Sendable {
    private let graphQL: GraphQLClient

    init(graphQL: GraphQLClient) {
        self.graphQL = graphQL
    }

    // MARK: - Sync

    /// Syncs contributions for a single member.
    ///
    /// When `organizationIDs` is non-empty the query is issued once per organization (using each
    /// org's GitHub global node ID) and the results are aggregated. This scopes contributions to
    /// only the repositories owned by the tracked organizations.
    ///
    /// When `organizationIDs` is empty the global query is used, returning contributions across
    /// all repositories the member has contributed to.
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

            // Full-replace sync: remove any existing contribution record for this member.
            for existing in member.contributions {
                existing.member = nil
                context.delete(existing)
            }

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

            member.contributionCount = totalCommits + totalPRs + totalReviews + totalIssues

            syncDailyContributions(from: dailyCounts, member: member, in: context)

            try? context.save()
        } catch {
            // Silent failure — keeps any existing data intact.
        }
    }

    // MARK: - Private

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

    @MainActor
    private func syncDailyContributions(
        from dailyCounts: [String: Int],
        member: Member,
        in context: ModelContext
    ) {
        // Full-replace: remove existing daily records.
        for existing in member.dailyContributions {
            existing.member = nil
            context.delete(existing)
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = .current

        for (dateString, count) in dailyCounts {
            guard let date = dateFormatter.date(from: dateString) else { continue }
            let record = DailyContribution(date: date, count: count)
            record.member = member
            context.insert(record)
        }
    }
}

// MARK: - Response types (private)

private struct ContributionsResponse: Decodable, Sendable {
    let user: UserNode?

    struct UserNode: Decodable, Sendable {
        let contributionsCollection: Collection

        struct Collection: Decodable, Sendable {
            let totalCommitContributions: Int
            let totalPullRequestContributions: Int
            let totalPullRequestReviewContributions: Int
            let totalIssueContributions: Int
            let contributionCalendar: ContributionCalendar
        }
    }

    struct ContributionCalendar: Decodable, Sendable {
        let weeks: [Week]

        struct Week: Decodable, Sendable {
            let contributionDays: [Day]

            struct Day: Decodable, Sendable {
                let date: String
                let contributionCount: Int
            }
        }
    }
}
