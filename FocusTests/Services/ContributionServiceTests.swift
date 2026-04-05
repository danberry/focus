import Foundation
import Testing
import SwiftData
@testable import Focus

@Suite("ContributionService Tests")
@MainActor
struct ContributionServiceTests {
    let mockHTTP = MockHTTPClient()

    private func makeService() -> ContributionService {
        let graphQL = GraphQLClient(httpClient: mockHTTP, tokenProvider: { "test-token" })
        return ContributionService(graphQL: graphQL)
    }

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Team.self, Member.self, MemberContribution.self, DailyContribution.self,
            configurations: config
        )
    }

    private func makeResponse(commits: Int = 10, prs: Int = 3, reviews: Int = 2, issues: Int = 1) -> String {
        """
        {
          "data": {
            "user": {
              "contributionsCollection": {
                "totalCommitContributions": \(commits),
                "totalPullRequestContributions": \(prs),
                "totalPullRequestReviewContributions": \(reviews),
                "totalIssueContributions": \(issues),
                "contributionCalendar": {
                  "weeks": [
                    {
                      "contributionDays": [
                        { "date": "2025-04-05", "contributionCount": \(commits) },
                        { "date": "2025-04-06", "contributionCount": 0 }
                      ]
                    }
                  ]
                }
              }
            }
          }
        }
        """
    }

    // MARK: - syncContributions creates record

    @Test func syncContributionsCreatesRecord() async throws {
        mockHTTP.setSuccess(json: makeResponse(commits: 10, prs: 3, reviews: 2, issues: 1))

        let container = try makeContainer()
        let context = container.mainContext
        let member = Member(name: "Alice", githubLogin: "alice")
        context.insert(member)

        await makeService().syncContributions(login: "alice", member: member, in: context)

        let contributions = member.contributions
        #expect(contributions.count == 1)

        let record = try #require(contributions.first)
        #expect(record.commits == 10)
        #expect(record.pullRequests == 3)
        #expect(record.reviews == 2)
        #expect(record.issues == 1)
    }

    // MARK: - Updates denormalized contributionCount

    @Test func syncContributionsUpdatesContributionCount() async throws {
        mockHTTP.setSuccess(json: makeResponse(commits: 10, prs: 3, reviews: 2, issues: 1))

        let container = try makeContainer()
        let context = container.mainContext
        let member = Member(name: "Alice", githubLogin: "alice")
        context.insert(member)

        await makeService().syncContributions(login: "alice", member: member, in: context)

        #expect(member.contributionCount == 16)
        #expect(member.totalContributions == 16)
    }

    // MARK: - Full-replace sync

    @Test func syncContributionsReplacesExistingRecord() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let member = Member(name: "Bob", githubLogin: "bob")
        context.insert(member)

        // Seed a stale record
        let stale = MemberContribution(
            commits: 99, pullRequests: 99, reviews: 99, issues: 99,
            periodStart: Date.distantPast, periodEnd: Date.distantPast, fetchedAt: Date.distantPast
        )
        stale.member = member
        context.insert(stale)
        try context.save()
        #expect(member.contributions.count == 1)

        mockHTTP.setSuccess(json: makeResponse(commits: 5, prs: 1, reviews: 0, issues: 2))
        await makeService().syncContributions(login: "bob", member: member, in: context)

        #expect(member.contributions.count == 1)
        let record = try #require(member.contributions.first)
        #expect(record.commits == 5)
        #expect(record.pullRequests == 1)
        #expect(record.reviews == 0)
        #expect(record.issues == 2)
        #expect(member.contributionCount == 8)
    }

    // MARK: - Silent failure keeps existing data

    @Test func syncContributionsKeepsExistingOnNetworkError() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let member = Member(name: "Carol", githubLogin: "carol")
        context.insert(member)

        let existing = MemberContribution(
            commits: 7, pullRequests: 2, reviews: 1, issues: 0,
            periodStart: Date(), periodEnd: Date(), fetchedAt: Date()
        )
        existing.member = member
        context.insert(existing)
        member.contributionCount = 10

        mockHTTP.setSuccess(json: "{}", statusCode: 403)
        await makeService().syncContributions(login: "carol", member: member, in: context)

        // Existing record and count are preserved
        #expect(member.contributions.count == 1)
        #expect(member.contributionCount == 10)
    }

    @Test func syncContributionsKeepsExistingOnGraphQLError() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let member = Member(name: "Dave", githubLogin: "dave")
        context.insert(member)

        let existing = MemberContribution(
            commits: 3, pullRequests: 1, reviews: 0, issues: 0,
            periodStart: Date(), periodEnd: Date(), fetchedAt: Date()
        )
        existing.member = member
        context.insert(existing)
        member.contributionCount = 4

        mockHTTP.setSuccess(json: """
        {
          "errors": [
            {
              "type": "VALIDATION",
              "message": "The total time spanned by 'from' and 'to' must not exceed 1 year"
            }
          ]
        }
        """)
        await makeService().syncContributions(login: "dave", member: member, in: context)

        #expect(member.contributions.count == 1)
        #expect(member.contributionCount == 4)
    }

    // MARK: - Null user in response

    @Test func syncContributionsHandlesNullUser() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let member = Member(name: "Ghost", githubLogin: "ghost")
        context.insert(member)

        mockHTTP.setSuccess(json: """
        {
          "data": {
            "user": null
          }
        }
        """)
        await makeService().syncContributions(login: "ghost", member: member, in: context)

        // No crash, no record created, contributionCount unchanged
        #expect(member.contributions.isEmpty)
        #expect(member.contributionCount == 0)
    }

    // MARK: - Sets period dates

    @Test func syncContributionsSetsApproximatePeriod() async throws {
        mockHTTP.setSuccess(json: makeResponse())

        let container = try makeContainer()
        let context = container.mainContext
        let member = Member(name: "Eve", githubLogin: "eve")
        context.insert(member)

        let before = Date()
        await makeService().syncContributions(login: "eve", member: member, in: context)
        let after = Date()

        let record = try #require(member.contributions.first)

        // periodEnd should be approximately now
        #expect(record.periodEnd >= before)
        #expect(record.periodEnd <= after)

        // periodStart should be approximately 365 days ago
        let expectedStart = Calendar.current.date(byAdding: .day, value: -365, to: before)!
        #expect(record.periodStart >= expectedStart.addingTimeInterval(-5))
        #expect(record.periodStart <= after)

        // fetchedAt should be approximately now
        #expect(record.fetchedAt >= before)
        #expect(record.fetchedAt <= after)
    }

    // MARK: - Sets back-reference

    @Test func syncContributionsSetsBackReference() async throws {
        mockHTTP.setSuccess(json: makeResponse())

        let container = try makeContainer()
        let context = container.mainContext
        let member = Member(name: "Frank", githubLogin: "frank")
        context.insert(member)

        await makeService().syncContributions(login: "frank", member: member, in: context)

        let record = try #require(member.contributions.first)
        #expect(record.member === member)
    }

    // MARK: - Uses GraphQL endpoint

    @Test func syncContributionsUsesGraphQLEndpoint() async throws {
        mockHTTP.setSuccess(json: makeResponse())

        let container = try makeContainer()
        let context = container.mainContext
        let member = Member(name: "Grace", githubLogin: "grace")
        context.insert(member)

        await makeService().syncContributions(login: "grace", member: member, in: context)

        let url = mockHTTP.lastRequest?.url
        #expect(url?.host == "api.github.com")
        #expect(url?.path == "/graphql")
    }

    // MARK: - Zero contributions

    @Test func syncContributionsHandlesZeroContributions() async throws {
        mockHTTP.setSuccess(json: makeResponse(commits: 0, prs: 0, reviews: 0, issues: 0))

        let container = try makeContainer()
        let context = container.mainContext
        let member = Member(name: "Hank", githubLogin: "hank")
        context.insert(member)

        await makeService().syncContributions(login: "hank", member: member, in: context)

        #expect(member.contributions.count == 1)
        #expect(member.contributionCount == 0)
        let record = try #require(member.contributions.first)
        #expect(record.commits == 0)
        #expect(record.pullRequests == 0)
        #expect(record.reviews == 0)
        #expect(record.issues == 0)
    }
}
