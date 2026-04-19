import Testing
import Foundation
import SwiftData
@testable import Focus

// MARK: - OrgDashboardViewTests

/// Tests for the computed health metrics displayed by ``OrgDashboardView``.
///
/// The view itself composes SwiftUI primitives — the interesting behavior is the
/// aggregation of department-level counts via SwiftData relationships, which is
/// what these tests exercise.
@Suite("OrgDashboardView")
@MainActor // Required because SwiftData model context operations run on the main actor.
struct OrgDashboardViewTests {

    // MARK: - Helpers

    /// Creates an in-memory `ModelContainer` with the dashboard-related types registered.
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: SavedOrganization.self,
            Department.self,
            Team.self,
            SavedRepository.self,
            Member.self,
            configurations: config
        )
    }

    // MARK: - Department metrics

    /// Verifies that a department surfaces its assigned teams via the `teams` relationship.
    @Test func departmentHealthCardTeamCount() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let dept = Department(name: "Engineering")
        context.insert(dept)
        let t1 = Team(name: "Backend", teamDescription: "")
        let t2 = Team(name: "Frontend", teamDescription: "")
        t1.department = dept
        t2.department = dept
        context.insert(t1)
        context.insert(t2)

        #expect(dept.teams.count == 2)
    }

    /// Verifies that a department aggregates repository counts across its teams.
    @Test func departmentHealthCardRepoCount() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let dept = Department(name: "Platform")
        context.insert(dept)
        let team = Team(name: "Infra", teamDescription: "")
        team.department = dept
        context.insert(team)
        let repo = SavedRepository(githubId: "1", owner: "acme", name: "infra", displayName: "Infra")
        repo.team = team
        context.insert(repo)

        let repoCount = dept.teams.flatMap(\.repositories).count
        #expect(repoCount == 1)
    }

    /// Verifies that a department rolls up the total open security alerts across all
    /// repositories owned by its teams.
    @Test func departmentHealthCardAlertCount() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let dept = Department(name: "Security")
        context.insert(dept)
        let team = Team(name: "AppSec", teamDescription: "")
        team.department = dept
        context.insert(team)
        let repo = SavedRepository(githubId: "2", owner: "acme", name: "auth", displayName: "Auth")
        repo.dependabotAlerts = 3
        repo.codeScanningAlerts = 1
        repo.team = team
        context.insert(repo)

        let alertCount = dept.teams.flatMap(\.repositories).reduce(0) { $0 + $1.totalSecurityAlerts }
        #expect(alertCount == 4)
    }

    /// Verifies that a department aggregates member counts across its teams.
    @Test func departmentHealthCardMemberCount() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let dept = Department(name: "Data")
        context.insert(dept)
        let team = Team(name: "Analytics", teamDescription: "")
        team.department = dept
        context.insert(team)
        let member = Member(name: "Alice", githubLogin: "alice")
        member.team = team
        context.insert(member)

        let memberCount = dept.teams.flatMap(\.members).count
        #expect(memberCount == 1)
    }

    // MARK: - Organization metrics

    /// Verifies that an organization with no departments exposes an empty list.
    @Test func orgWithNoDepartmentsHasEmptySortedList() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let org = SavedOrganization(githubId: "1", login: "acme")
        context.insert(org)

        #expect(org.departments.isEmpty)
    }
}
