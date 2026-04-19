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

        let briefing = await makeService().generate(in: context)

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

        let briefing = await makeService().generate(in: context)

        #expect(briefing.kpis.security.critical == 2)
    }

    /// Verifies that a member with no contributions in the previous week appears in `blocked.members`.
    @Test func idleMemberAppearsInBlocked() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let member = Member(name: "Priya Shah", githubId: 42, githubLogin: "priyashah")
        context.insert(member)

        let briefing = await makeService().generate(in: context)

        #expect(briefing.blocked.members.contains { $0.name == "Priya Shah" })
    }

    /// Verifies that the API-returned `issueCount` propagates to the shipping total.
    @Test func apiIssueCountDrivesShippingValue() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let repo = SavedRepository(githubId: "1", owner: "acme", name: "widget", displayName: "Widget")
        context.insert(repo)

        let briefing = await makeService(issueCount: 7).generate(in: context)

        #expect(briefing.kpis.shipping.value == 7)
    }

    /// Verifies that the formatted week range string contains the editorial em dash separator.
    @Test func weekRangeContainsEmDash() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let briefing = await makeService().generate(in: context)

        #expect(briefing.weekRange.contains("—"))
    }
}
