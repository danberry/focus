import Foundation
import Testing
import SwiftData
@testable import Focus

/// Tests for `IssueVelocityService`.
@Suite("IssueVelocityService Tests")
@MainActor
struct IssueVelocityServiceTests {
    let mockHTTP = MockHTTPClient()

    // MARK: - Setup

    private func makeService() -> IssueVelocityService {
        let graphQL = GraphQLClient(httpClient: mockHTTP, tokenProvider: { "test-token" })
        return IssueVelocityService(graphQL: graphQL)
    }

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: SavedRepository.self, IssueVelocity.self, RepositoryVelocity.self, Team.self, Department.self, SavedOrganization.self,
            configurations: config
        )
    }

    private func makeResponse(
        w7c: Int = 5, w7p: Int = 3,
        d30c: Int = 20, d30p: Int = 15,
        d90c: Int = 60, d90p: Int = 55,
        ytdC: Int = 80, ytdP: Int = 70
    ) -> String {
        """
        {
          "data": {
            "w7Current":  { "issueCount": \(w7c) },
            "w7Prior":    { "issueCount": \(w7p) },
            "d30Current": { "issueCount": \(d30c) },
            "d30Prior":   { "issueCount": \(d30p) },
            "d90Current": { "issueCount": \(d90c) },
            "d90Prior":   { "issueCount": \(d90p) },
            "ytdCurrent": { "issueCount": \(ytdC) },
            "ytdPrior":   { "issueCount": \(ytdP) }
          }
        }
        """
    }

    // MARK: - syncIssueVelocity

    /// Verifies that syncing creates exactly four issue velocity records, one per period.
    @Test func syncIssueVelocityCreatesFourRecords() async throws {
        mockHTTP.setSuccess(json: makeResponse())

        let container = try makeContainer()
        let context = container.mainContext
        let repo = SavedRepository(githubId: "1", owner: "acme", name: "widget", displayName: "Widget")
        context.insert(repo)

        await makeService().syncIssueVelocity(owner: "acme", repo: "widget", repository: repo, in: context)

        #expect(repo.issueVelocityMetrics.count == 4)
        let periods = Set(repo.issueVelocityMetrics.map(\.periodType))
        #expect(periods == ["7D", "30D", "90D", "YTD"])
    }

    /// Verifies that current and prior counts are stored correctly for each period.
    @Test func syncIssueVelocityStoresCorrectCounts() async throws {
        mockHTTP.setSuccess(json: makeResponse(w7c: 5, w7p: 3, d30c: 20, d30p: 15, d90c: 60, d90p: 55, ytdC: 80, ytdP: 70))

        let container = try makeContainer()
        let context = container.mainContext
        let repo = SavedRepository(githubId: "1", owner: "acme", name: "widget", displayName: "Widget")
        context.insert(repo)

        await makeService().syncIssueVelocity(owner: "acme", repo: "widget", repository: repo, in: context)

        let record30 = try #require(repo.issueVelocityMetrics.first { $0.periodType == "30D" })
        #expect(record30.currentCount == 20)
        #expect(record30.priorCount == 15)

        let recordYtd = try #require(repo.issueVelocityMetrics.first { $0.periodType == "YTD" })
        #expect(recordYtd.currentCount == 80)
        #expect(recordYtd.priorCount == 70)
    }

    /// Verifies that a second sync replaces previously persisted records rather than appending.
    @Test func syncIssueVelocityFullReplaces() async throws {
        mockHTTP.setSuccess(json: makeResponse(d30c: 99, d30p: 88))

        let container = try makeContainer()
        let context = container.mainContext
        let repo = SavedRepository(githubId: "1", owner: "acme", name: "widget", displayName: "Widget")
        context.insert(repo)

        await makeService().syncIssueVelocity(owner: "acme", repo: "widget", repository: repo, in: context)
        #expect(repo.issueVelocityMetrics.count == 4)

        mockHTTP.setSuccess(json: makeResponse(d30c: 42, d30p: 31))
        await makeService().syncIssueVelocity(owner: "acme", repo: "widget", repository: repo, in: context)

        #expect(repo.issueVelocityMetrics.count == 4)
        let record = try #require(repo.issueVelocityMetrics.first { $0.periodType == "30D" })
        #expect(record.currentCount == 42)
        #expect(record.priorCount == 31)
    }

    /// Verifies that a network error leaves existing issue velocity records untouched.
    @Test func syncIssueVelocitySilentlyFailsOnError() async throws {
        mockHTTP.setSuccess(json: makeResponse(d30c: 10, d30p: 8))

        let container = try makeContainer()
        let context = container.mainContext
        let repo = SavedRepository(githubId: "1", owner: "acme", name: "widget", displayName: "Widget")
        context.insert(repo)

        await makeService().syncIssueVelocity(owner: "acme", repo: "widget", repository: repo, in: context)
        #expect(repo.issueVelocityMetrics.count == 4)

        mockHTTP.setFailure(URLError(.notConnectedToInternet))
        await makeService().syncIssueVelocity(owner: "acme", repo: "widget", repository: repo, in: context)

        #expect(repo.issueVelocityMetrics.count == 4)
        let record = try #require(repo.issueVelocityMetrics.first { $0.periodType == "30D" })
        #expect(record.currentCount == 10)
    }

    /// Verifies that issue velocity records use the `VelocityComparison` type for trend calculation.
    @Test func issueVelocityComparisonReflectsCurrentAndPrior() async throws {
        mockHTTP.setSuccess(json: makeResponse(w7c: 12, w7p: 8))

        let container = try makeContainer()
        let context = container.mainContext
        let repo = SavedRepository(githubId: "1", owner: "acme", name: "widget", displayName: "Widget")
        context.insert(repo)

        await makeService().syncIssueVelocity(owner: "acme", repo: "widget", repository: repo, in: context)

        let record = try #require(repo.issueVelocityMetrics.first { $0.periodType == "7D" })
        let comparison = record.comparison
        #expect(comparison.current == 12)
        #expect(comparison.prior == 8)
        #expect(comparison.trend == .up)
        #expect(comparison.delta == 4)
    }

    // MARK: - buildDateWindows

    /// Verifies that prior windows cover the same calendar dates one year back.
    @Test func dateWindowsPriorIsSameCalendarDatesOneYearBack() throws {
        let service = makeService()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let today = try #require(cal.date(from: DateComponents(year: 2026, month: 4, day: 6)))

        let windows = try #require(service.buildDateWindows(today: today))

        #expect(windows.w30.current == "2026-03-07..2026-04-06")
        #expect(windows.w30.prior   == "2025-03-07..2025-04-06")

        #expect(windows.w7.current == "2026-03-30..2026-04-06")
        #expect(windows.w7.prior   == "2025-03-30..2025-04-06")

        #expect(windows.w90.current == "2026-01-06..2026-04-06")
        #expect(windows.w90.prior   == "2025-01-06..2025-04-06")

        #expect(windows.ytd.current == "2026-01-01..2026-04-06")
        #expect(windows.ytd.prior   == "2025-01-01..2025-04-06")
    }

    /// Verifies that the YTD window is a single-day range when today is January 1st.
    @Test func dateWindowsYTDOnJanFirst() throws {
        let service = makeService()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let jan1 = try #require(cal.date(from: DateComponents(year: 2026, month: 1, day: 1)))

        let windows = try #require(service.buildDateWindows(today: jan1))

        #expect(windows.ytd.current == "2026-01-01..2026-01-01")
        #expect(windows.ytd.prior   == "2025-01-01..2025-01-01")
    }
}
