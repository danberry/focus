import Foundation
import Testing
import SwiftData
@testable import Focus

/// Tests for `BriefingService`.
@Suite("BriefingService")
@MainActor // Required because `generate(in:)` is @MainActor.
struct BriefingServiceTests {
    let mockHTTP = MockHTTPClient()

    // MARK: - Setup

    /// Creates a `BriefingService` wired to the shared `MockHTTPClient` whose
    /// stubbed response reports `issueCount` as the supplied value.
    private func makeService(issueCount: Int = 0) -> BriefingService {
        mockHTTP.setSuccess(json: #"{"data":{"search":{"issueCount":\#(issueCount)}}}"#)
        let graphQL = GraphQLClient(httpClient: mockHTTP, tokenProvider: { "test-token" })
        return BriefingService(graphQL: graphQL)
    }

    /// Creates an in-memory `ModelContainer` registering the model types
    /// `BriefingService` reads from SwiftData.
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: SavedRepository.self, DependabotAlert.self,
            Member.self, DailyContribution.self, Team.self, Department.self, SavedOrganization.self,
            configurations: config
        )
    }

    // MARK: - generate

    /// Verifies that an empty store yields a briefing with zero merged PRs.
    @Test func emptyStoreReturnsZeroShipping() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let briefing = await makeService().generate(scope: .all, in: context)

        #expect(briefing.kpis.shipping.value == 0)
    }

    /// Verifies that exactly the `"critical"`-severity Dependabot alerts are counted.
    @Test func criticalAlertCountIsCorrect() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let repo = SavedRepository(githubId: "1", owner: "acme", name: "widget", displayName: "Widget")
        context.insert(repo)

        let critical1 = DependabotAlert(
            alertNumber: 1, packageName: "lodash", severity: "critical",
            fixVersion: nil, createdAt: Date()
        )
        let critical2 = DependabotAlert(
            alertNumber: 2, packageName: "axios", severity: "critical",
            fixVersion: nil, createdAt: Date()
        )
        let high = DependabotAlert(
            alertNumber: 3, packageName: "jquery", severity: "high",
            fixVersion: nil, createdAt: Date()
        )
        context.insert(critical1)
        context.insert(critical2)
        context.insert(high)
        repo.dependabotAlertDetails.append(critical1)
        repo.dependabotAlertDetails.append(critical2)
        repo.dependabotAlertDetails.append(high)

        let briefing = await makeService().generate(scope: .all, in: context)

        #expect(briefing.kpis.security.critical == 2)
    }

    /// Verifies that a member with no contributions in the previous week appears in `blocked.members`.
    @Test func idleMemberAppearsInBlocked() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let member = Member(name: "Priya Shah", githubId: 42, githubLogin: "priyashah")
        context.insert(member)

        let briefing = await makeService().generate(scope: .all, in: context)

        #expect(briefing.blocked.members.contains { $0.name == "Priya Shah" })
    }

    /// Verifies that the API-returned `issueCount` propagates to the shipping total.
    @Test func apiIssueCountDrivesShippingValue() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let repo = SavedRepository(githubId: "1", owner: "acme", name: "widget", displayName: "Widget")
        context.insert(repo)

        let briefing = await makeService(issueCount: 7).generate(scope: .all, in: context)

        #expect(briefing.kpis.shipping.value == 7)
    }

    /// Verifies that the formatted week range string contains the editorial em dash separator.
    @Test func weekRangeContainsEmDash() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let briefing = await makeService().generate(scope: .all, in: context)

        #expect(briefing.weekRange.contains("—"))
    }

    // MARK: - scope

    /// Verifies that a team-scoped briefing only counts merged PRs for repositories assigned to that team.
    ///
    /// Creates one repo assigned to the team and one unassigned. The stubbed GraphQL response
    /// returns `issueCount == 5` for every search, so the shipping total equals the number of
    /// repos whose PRs actually get counted (5 for the assigned repo, nothing for the unassigned one).
    @Test func scopedToTeamFiltersRepos() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let team = Team(name: "Platform", teamDescription: "")
        context.insert(team)

        let assignedRepo = SavedRepository(githubId: "1", owner: "acme", name: "assigned", displayName: "Assigned")
        assignedRepo.team = team
        context.insert(assignedRepo)

        let unassignedRepo = SavedRepository(githubId: "2", owner: "acme", name: "loose", displayName: "Loose")
        context.insert(unassignedRepo)

        let briefing = await makeService(issueCount: 5).generate(scope: .team(team), in: context)

        #expect(briefing.kpis.shipping.value == 5)
    }

    /// Verifies that a department-scoped briefing only includes idle members whose team rolls up to that department.
    ///
    /// Creates a member on a team inside the target department and a second member with no team.
    /// Only the in-department member should appear in `blocked.members`.
    @Test func scopedToDepartmentFiltersMembers() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let dept = Department(name: "Engineering")
        context.insert(dept)

        let team = Team(name: "Infra", teamDescription: "")
        team.department = dept
        context.insert(team)

        let inDept = Member(name: "Ada Lovelace", githubId: 1, githubLogin: "ada")
        inDept.team = team
        context.insert(inDept)

        let outOfDept = Member(name: "Grace Hopper", githubId: 2, githubLogin: "grace")
        context.insert(outOfDept)

        let briefing = await makeService().generate(scope: .department(dept), in: context)

        #expect(briefing.blocked.members.contains { $0.name == "Ada Lovelace" })
        #expect(!briefing.blocked.members.contains { $0.name == "Grace Hopper" })
    }
}
