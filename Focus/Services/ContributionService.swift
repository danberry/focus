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
        guard let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: now) else { return }

        let formatter = ISO8601DateFormatter()
        let fromString = formatter.string(from: thirtyDaysAgo)
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
                periodStart: thirtyDaysAgo,
                periodEnd: now,
                fetchedAt: now
            )
            contribution.member = member
            context.insert(contribution)

            member.contributionCount = collection.totalCommitContributions
                + collection.totalPullRequestContributions
                + collection.totalPullRequestReviewContributions
                + collection.totalIssueContributions

            try? context.save()
        } catch {
            // Silent failure — keeps any existing data intact.
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
        }
    }
}
