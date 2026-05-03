import Foundation
import Testing
import SwiftData
@testable import Focus

/// Tests for ``ContributionService``.
@Suite("ContributionService Tests")
@MainActor // Required because ContributionService.syncContributions is @MainActor
struct ContributionServiceTests {
    let mockHTTP = MockHTTPClient()

    /// Creates a `ContributionService` wired to the shared `MockHTTPClient`.
    private func makeService() -> ContributionService {
        let graphQL = GraphQLClient(httpClient: mockHTTP, tokenProvider: { "test-token" })
        return ContributionService(graphQL: graphQL)
    }

    /// Creates an in-memory `ModelContainer` with the contribution model types registered.
    private func makeContainer() throws -> ModelContainer { try makeTestContainer() }

    /// Builds a minimal GraphQL contribution response JSON string with configurable contribution counts.
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

    /// Verifies that a successful sync creates a contribution record with the correct field values.
    @Test func syncContributionsCreatesRecord() async throws {
        mockHTTP.setSuccess(json: makeResponse(commits: 10, prs: 3, reviews: 2, issues: 1))

        let container = try makeContainer()
        let context = container.mainContext
        let member = Member(name: "Alice", githubLogin: "alice")
        context.insert(member)

        await makeService().syncContributions(login: "alice", member: member, in: context)

        let contributions = (member.contributions ?? [])
        #expect(contributions.count == 1)

        let record = try #require(contributions.first)
        #expect(record.commits == 10)
        #expect(record.pullRequests == 3)
        #expect(record.reviews == 2)
        #expect(record.issues == 1)
    }

    /// Verifies that a successful sync updates the member's denormalized contribution count.
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

    /// Verifies that a second sync replaces previously persisted contributions rather than appending.
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
        #expect((member.contributions ?? []).count == 1)

        mockHTTP.setSuccess(json: makeResponse(commits: 5, prs: 1, reviews: 0, issues: 2))
        await makeService().syncContributions(login: "bob", member: member, in: context)

        #expect((member.contributions ?? []).count == 1)
        let record = try #require(member.contributions?.first)
        #expect(record.commits == 5)
        #expect(record.pullRequests == 1)
        #expect(record.reviews == 0)
        #expect(record.issues == 2)
        #expect(member.contributionCount == 8)
    }

    /// Verifies that a 403 response leaves existing contributions and count unchanged.
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
        #expect((member.contributions ?? []).count == 1)
        #expect(member.contributionCount == 10)
    }

    /// Verifies that a GraphQL validation error leaves existing contributions and count unchanged.
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

        #expect((member.contributions ?? []).count == 1)
        #expect(member.contributionCount == 4)
    }

    /// Verifies that a null user in the response creates no record and leaves contribution count unchanged.
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
        #expect((member.contributions ?? []).isEmpty)
        #expect(member.contributionCount == 0)
    }

    /// Verifies that the synced record's period and fetch dates are set to approximately the current time and one year prior.
    @Test func syncContributionsSetsApproximatePeriod() async throws {
        mockHTTP.setSuccess(json: makeResponse())

        let container = try makeContainer()
        let context = container.mainContext
        let member = Member(name: "Eve", githubLogin: "eve")
        context.insert(member)

        let before = Date()
        await makeService().syncContributions(login: "eve", member: member, in: context)
        let after = Date()

        let record = try #require(member.contributions?.first)

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

    /// Verifies that the synced contribution record's back-reference points to the owning member.
    @Test func syncContributionsSetsBackReference() async throws {
        mockHTTP.setSuccess(json: makeResponse())

        let container = try makeContainer()
        let context = container.mainContext
        let member = Member(name: "Frank", githubLogin: "frank")
        context.insert(member)

        await makeService().syncContributions(login: "frank", member: member, in: context)

        let record = try #require(member.contributions?.first)
        #expect(record.member === member)
    }

    /// Verifies that contribution data is fetched from the GitHub GraphQL endpoint.
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

    /// Verifies that members without a GitHub login are skipped during a multi-member sync loop.
    @Test func syncAllSkipsMembersWithoutGitHubLogin() async throws {
        mockHTTP.setSuccess(json: makeResponse(commits: 5, prs: 1, reviews: 0, issues: 0))

        let container = try makeContainer()
        let context = container.mainContext
        let linked = Member(name: "Alice", githubLogin: "alice")
        let unlinked = Member(name: "Bob")  // no GitHub login
        context.insert(linked)
        context.insert(unlinked)

        let service = makeService()
        for member in [linked, unlinked] {
            guard let login = member.githubLogin else { continue }
            await service.syncContributions(login: login, member: member, in: context)
        }

        #expect((linked.contributions ?? []).count == 1)
        #expect((unlinked.contributions ?? []).isEmpty)
        #expect(unlinked.contributionCount == 0)
    }

    /// Verifies that each linked member receives independent contribution data during a multi-member sync.
    @Test func syncAllSyncsEachLinkedMemberIndependently() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let alice = Member(name: "Alice", githubLogin: "alice")
        let bob = Member(name: "Bob", githubLogin: "bob")
        context.insert(alice)
        context.insert(bob)

        let service = makeService()

        // First call returns Alice's data.
        mockHTTP.setSuccess(json: makeResponse(commits: 10, prs: 2, reviews: 1, issues: 0))
        await service.syncContributions(login: "alice", member: alice, in: context)

        // Second call returns Bob's data.
        mockHTTP.setSuccess(json: makeResponse(commits: 3, prs: 0, reviews: 0, issues: 1))
        await service.syncContributions(login: "bob", member: bob, in: context)

        #expect((alice.contributions ?? []).count == 1)
        #expect(alice.contributions?.first?.commits == 10)
        #expect((bob.contributions ?? []).count == 1)
        #expect(bob.contributions?.first?.commits == 3)
    }

    /// Verifies that a response with all-zero counts creates a record with zero values and a zero contribution count.
    @Test func syncContributionsHandlesZeroContributions() async throws {
        mockHTTP.setSuccess(json: makeResponse(commits: 0, prs: 0, reviews: 0, issues: 0))

        let container = try makeContainer()
        let context = container.mainContext
        let member = Member(name: "Hank", githubLogin: "hank")
        context.insert(member)

        await makeService().syncContributions(login: "hank", member: member, in: context)

        #expect((member.contributions ?? []).count == 1)
        #expect(member.contributionCount == 0)
        let record = try #require(member.contributions?.first)
        #expect(record.commits == 0)
        #expect(record.pullRequests == 0)
        #expect(record.reviews == 0)
        #expect(record.issues == 0)
    }

    /// Verifies that contributions are fetched and persisted correctly when a single organization ID is provided.
    @Test func syncContributionsWithOneOrgUsesOrgQuery() async throws {
        mockHTTP.setSuccess(json: makeResponse(commits: 4, prs: 1, reviews: 0, issues: 1))

        let container = try makeContainer()
        let context = container.mainContext
        let member = Member(name: "Ivy", githubLogin: "ivy")
        context.insert(member)

        await makeService().syncContributions(
            login: "ivy", member: member, organizationIDs: ["ORG_NODE_ID_1"], in: context
        )

        let record = try #require(member.contributions?.first)
        #expect(record.commits == 4)
        #expect(record.pullRequests == 1)
        #expect(record.reviews == 0)
        #expect(record.issues == 1)
        #expect(member.contributionCount == 6)
    }

    /// Verifies that contribution totals are summed across multiple organization IDs into a single record.
    @Test func syncContributionsAggregatesAcrossOrganizations() async throws {
        // Two orgs: first returns commits=5, prs=2; second returns commits=3, issues=1.
        mockHTTP.enqueueSuccess(json: makeResponse(commits: 5, prs: 2, reviews: 0, issues: 0))
        mockHTTP.enqueueSuccess(json: makeResponse(commits: 3, prs: 0, reviews: 0, issues: 1))

        let container = try makeContainer()
        let context = container.mainContext
        let member = Member(name: "Jack", githubLogin: "jack")
        context.insert(member)

        await makeService().syncContributions(
            login: "jack", member: member, organizationIDs: ["ORG_1", "ORG_2"], in: context
        )

        #expect((member.contributions ?? []).count == 1)
        let record = try #require(member.contributions?.first)
        #expect(record.commits == 8)
        #expect(record.pullRequests == 2)
        #expect(record.reviews == 0)
        #expect(record.issues == 1)
        #expect(member.contributionCount == 11)
    }

    /// Verifies that daily contribution counts for the same date are summed across multiple organization IDs.
    @Test func syncContributionsAggregatesDailyCountsAcrossOrganizations() async throws {
        // Two orgs both have activity on 2025-04-05 — their daily counts should be summed.
        let org1Response = """
        {
          "data": {
            "user": {
              "contributionsCollection": {
                "totalCommitContributions": 3,
                "totalPullRequestContributions": 0,
                "totalPullRequestReviewContributions": 0,
                "totalIssueContributions": 0,
                "contributionCalendar": {
                  "weeks": [
                    { "contributionDays": [{ "date": "2025-04-05", "contributionCount": 3 }] }
                  ]
                }
              }
            }
          }
        }
        """
        let org2Response = """
        {
          "data": {
            "user": {
              "contributionsCollection": {
                "totalCommitContributions": 2,
                "totalPullRequestContributions": 0,
                "totalPullRequestReviewContributions": 0,
                "totalIssueContributions": 0,
                "contributionCalendar": {
                  "weeks": [
                    { "contributionDays": [{ "date": "2025-04-05", "contributionCount": 2 }] }
                  ]
                }
              }
            }
          }
        }
        """
        mockHTTP.enqueueSuccess(json: org1Response)
        mockHTTP.enqueueSuccess(json: org2Response)

        let container = try makeContainer()
        let context = container.mainContext
        let member = Member(name: "Kim", githubLogin: "kim")
        context.insert(member)

        await makeService().syncContributions(
            login: "kim", member: member, organizationIDs: ["ORG_1", "ORG_2"], in: context
        )

        // The single day "2025-04-05" should have a merged count of 3 + 2 = 5.
        #expect((member.dailyContributions ?? []).count == 1)
        let day = try #require(member.dailyContributions?.first)
        #expect(day.count == 5)
    }

    /// Verifies that a null-user response for one organization is skipped and other organizations' data is used.
    @Test func syncContributionsSkipsOrgWithNullUser() async throws {
        // First org returns null user; second org has real data — only second counts.
        let nullUserResponse = """
        { "data": { "user": null } }
        """
        mockHTTP.enqueueSuccess(json: nullUserResponse)
        mockHTTP.enqueueSuccess(json: makeResponse(commits: 7, prs: 1, reviews: 0, issues: 0))

        let container = try makeContainer()
        let context = container.mainContext
        let member = Member(name: "Lee", githubLogin: "lee")
        context.insert(member)

        await makeService().syncContributions(
            login: "lee", member: member, organizationIDs: ["ORG_NULL", "ORG_REAL"], in: context
        )

        let record = try #require(member.contributions?.first)
        #expect(record.commits == 7)
        #expect(record.pullRequests == 1)
        #expect(member.contributionCount == 8)
    }

    /// Verifies that existing contributions are preserved when all organization queries return null users.
    @Test func syncContributionsKeepsExistingWhenAllOrgsReturnNullUser() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let member = Member(name: "Mo", githubLogin: "mo")
        context.insert(member)

        let existing = MemberContribution(
            commits: 5, pullRequests: 1, reviews: 0, issues: 0,
            periodStart: Date(), periodEnd: Date(), fetchedAt: Date()
        )
        existing.member = member
        context.insert(existing)
        member.contributionCount = 6

        mockHTTP.enqueueSuccess(json: "{ \"data\": { \"user\": null } }")
        mockHTTP.enqueueSuccess(json: "{ \"data\": { \"user\": null } }")

        await makeService().syncContributions(
            login: "mo", member: member, organizationIDs: ["ORG_1", "ORG_2"], in: context
        )

        // All orgs returned null — existing data must be preserved.
        #expect((member.contributions ?? []).count == 1)
        #expect(member.contributionCount == 6)
    }
}
