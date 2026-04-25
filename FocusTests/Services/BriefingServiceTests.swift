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

    /// Creates a `BriefingService` wired to the shared `MockHTTPClient`.
    ///
    /// The stub returns a `MergedPRs` response with `count` nodes all attributed to
    /// `repoKey`. Calls that expect a different shape (e.g. `issueCount`-only queries)
    /// decode the same JSON and silently return 0, which is fine for shipping-agnostic tests.
    private func makeService(mergedPRCount: Int = 0, repoKey: String = "") -> BriefingService {
        let ts = "2026-04-14T10:00:00Z"
        let nodeJSON = { (i: Int) -> String in
            "{\"number\":\(i),\"title\":\"PR \(i)\",\"createdAt\":\"\(ts)\",\"mergedAt\":\"\(ts)\","
            + "\"author\":{\"login\":\"user\"},\"url\":\"https://github.com/\(repoKey)/pull/\(i)\","
            + "\"repository\":{\"nameWithOwner\":\"\(repoKey)\"},\"additions\":5,\"deletions\":3,"
            + "\"reviews\":{\"nodes\":[]},\"commits\":{\"nodes\":[{\"commit\":{\"statusCheckRollup\":null}}]}}"
        }
        let nodesArray = mergedPRCount > 0 && !repoKey.isEmpty
            ? (1...mergedPRCount).map(nodeJSON).joined(separator: ",")
            : ""
        let json = "{\"data\":{\"search\":{\"pageInfo\":{\"endCursor\":null,\"hasNextPage\":false},\"nodes\":[\(nodesArray)]}}}"
        mockHTTP.setSuccess(json: json)
        let graphQL = GraphQLClient(httpClient: mockHTTP, tokenProvider: { "test-token" })
        return BriefingService(graphQL: graphQL)
    }

    /// Creates an in-memory `ModelContainer` with the same schema as the production container.
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: SavedRepository.self, DependabotAlert.self,
            Member.self, MemberContribution.self, DailyContribution.self,
            Team.self, Department.self, SavedOrganization.self,
            Discipline.self, JobTitle.self, SecurityWeeklySnapshot.self,
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

    /// Verifies that members in a discipline with `tracksGitHubActivity == false` are excluded
    /// from the blocked list even when they have zero contributions for the week.
    @Test func memberInNonGitHubDisciplineIsNotFlaggedAsIdle() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let discipline = Discipline(name: "Design", tracksGitHubActivity: false)
        context.insert(discipline)
        let jobTitle = JobTitle(name: "Product Designer")
        context.insert(jobTitle)
        discipline.jobTitles.append(jobTitle)

        let member = Member(name: "Cleo Park", githubId: 99, githubLogin: "cleopark")
        member.jobTitle = jobTitle
        context.insert(member)

        let briefing = await makeService().generate(scope: .all, in: context)

        #expect(!briefing.blocked.members.contains { $0.name == "Cleo Park" })
    }

    /// Verifies that merged PR nodes returned by the API propagate to the shipping total.
    @Test func apiMergedPRCountDrivesShippingValue() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let repo = SavedRepository(githubId: "1", owner: "acme", name: "widget", displayName: "Widget")
        context.insert(repo)

        let briefing = await makeService(mergedPRCount: 7, repoKey: "acme/widget").generate(scope: .all, in: context)

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
    /// Creates one repo assigned to the team and one unassigned. The stub returns 5 nodes for
    /// the assigned repo, so `shipping.value` equals 5 — the unassigned repo is never queried.
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

        let briefing = await makeService(mergedPRCount: 5, repoKey: "acme/assigned").generate(scope: .team(team), in: context)

        #expect(briefing.kpis.shipping.value == 5)
    }

    /// Verifies that a repository marked `isInMaintenance` is not surfaced as the lowest-volume
    /// repo in the attention items, even when it has fewer merged PRs than active repos.
    @Test func maintenanceRepoIsExcludedFromLowestVolumeAttention() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let activeRepo = SavedRepository(githubId: "1", owner: "acme", name: "active", displayName: "Active")
        context.insert(activeRepo)

        let maintenanceRepo = SavedRepository(githubId: "2", owner: "acme", name: "legacy", displayName: "Legacy")
        maintenanceRepo.isInMaintenance = true
        context.insert(maintenanceRepo)

        // Both repos get the same PR count; the maintenance repo must still be excluded from
        // the lowest-volume attention slot regardless of count parity.
        let briefing = await makeService(mergedPRCount: 10, repoKey: "acme/active").generate(scope: .all, in: context)

        #expect(!briefing.attention[2].title.contains("Legacy"))
    }

    /// Verifies that `medianMerge` is nil when there are no tracked repositories,
    /// since cycle time requires actual merged PRs.
    @Test func cycleTimeIsNilWithNoRepos() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let briefing = await makeService().generate(scope: .all, in: context)

        #expect(briefing.kpis.medianMerge == nil)
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
