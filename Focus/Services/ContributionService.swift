import Foundation
import SwiftData

// MARK: - ContributionService

struct ContributionService: Sendable {
    private let graphQL: GraphQLClient

    init(graphQL: GraphQLClient) {
        self.graphQL = graphQL
    }

    // MARK: - Sync

    @MainActor
    func syncContributions(login: String, member: Member, in context: ModelContext) async {
        let now = Date()
        guard let oneYearAgo = Calendar.current.date(byAdding: .day, value: -365, to: now) else { return }

        let formatter = ISO8601DateFormatter()
        let fromString = formatter.string(from: oneYearAgo)
        let toString = formatter.string(from: now)

        do {
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

            // Full-replace sync: remove any existing contribution record for this member.
            for existing in member.contributions {
                existing.member = nil
                context.delete(existing)
            }

            let contribution = MemberContribution(
                commits: collection.totalCommitContributions,
                pullRequests: collection.totalPullRequestContributions,
                reviews: collection.totalPullRequestReviewContributions,
                issues: collection.totalIssueContributions,
                periodStart: oneYearAgo,
                periodEnd: now,
                fetchedAt: now
            )
            contribution.member = member
            context.insert(contribution)

            member.contributionCount = collection.totalCommitContributions
                + collection.totalPullRequestContributions
                + collection.totalPullRequestReviewContributions
                + collection.totalIssueContributions

            // Sync daily contributions from the contribution calendar.
            syncDailyContributions(
                from: collection.contributionCalendar,
                member: member,
                in: context
            )

            try? context.save()
        } catch {
            // Silent failure — keeps any existing data intact.
        }
    }

    // MARK: - Private

    @MainActor
    private func syncDailyContributions(
        from calendar: ContributionsResponse.ContributionCalendar,
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

        for week in calendar.weeks {
            for day in week.contributionDays {
                guard let date = dateFormatter.date(from: day.date) else { continue }
                let record = DailyContribution(date: date, count: day.contributionCount)
                record.member = member
                context.insert(record)
            }
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
