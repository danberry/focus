import Foundation
import Testing
import SwiftData
@testable import Focus

/// Tests for `VelocityService`.
@Suite("VelocityService Tests")
@MainActor // Required because syncVelocity is @MainActor
struct VelocityServiceTests {
    let mockHTTP = MockHTTPClient()

    // MARK: - Setup

    /// Creates a `VelocityService` wired to the shared `MockHTTPClient`.
    private func makeService() -> VelocityService {
        let graphQL = GraphQLClient(httpClient: mockHTTP, tokenProvider: { "test-token" })
        return VelocityService(graphQL: graphQL)
    }

    /// Creates an in-memory `ModelContainer` with velocity model types registered.
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: SavedRepository.self, RepositoryVelocity.self,
            configurations: config
        )
    }

    /// Creates a JSON response string with configurable merged PR counts for all four velocity periods.
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

    // MARK: - syncVelocity

    /// Verifies that syncing creates exactly four velocity records, one per period.
    @Test func syncVelocityCreatesFourRecords() async throws {
        mockHTTP.setSuccess(json: makeResponse())

        let container = try makeContainer()
        let context = container.mainContext
        let repo = SavedRepository(githubId: "1", owner: "acme", name: "widget", displayName: "Widget")
        context.insert(repo)

        await makeService().syncVelocity(owner: "acme", repo: "widget", repository: repo, in: context)

        #expect(repo.velocityMetrics.count == 4)
        let periods = Set(repo.velocityMetrics.map(\.periodType))
        #expect(periods == ["7D", "30D", "90D", "YTD"])
    }

    /// Verifies that current and prior counts are stored correctly for each period.
    @Test func syncVelocityStoresCorrectCounts() async throws {
        mockHTTP.setSuccess(json: makeResponse(w7c: 5, w7p: 3, d30c: 20, d30p: 15, d90c: 60, d90p: 55, ytdC: 80, ytdP: 70))

        let container = try makeContainer()
        let context = container.mainContext
        let repo = SavedRepository(githubId: "1", owner: "acme", name: "widget", displayName: "Widget")
        context.insert(repo)

        await makeService().syncVelocity(owner: "acme", repo: "widget", repository: repo, in: context)

        let record30 = try #require(repo.velocityMetrics.first { $0.periodType == "30D" })
        #expect(record30.currentCount == 20)
        #expect(record30.priorCount == 15)

        let recordYtd = try #require(repo.velocityMetrics.first { $0.periodType == "YTD" })
        #expect(recordYtd.currentCount == 80)
        #expect(recordYtd.priorCount == 70)
    }

    /// Verifies that a second sync replaces previously persisted records rather than appending.
    @Test func syncVelocityFullReplaces() async throws {
        mockHTTP.setSuccess(json: makeResponse(d30c: 99, d30p: 88))

        let container = try makeContainer()
        let context = container.mainContext
        let repo = SavedRepository(githubId: "1", owner: "acme", name: "widget", displayName: "Widget")
        context.insert(repo)

        // First sync
        await makeService().syncVelocity(owner: "acme", repo: "widget", repository: repo, in: context)
        #expect(repo.velocityMetrics.count == 4)

        // Second sync — should replace, not accumulate
        mockHTTP.setSuccess(json: makeResponse(d30c: 42, d30p: 31))
        await makeService().syncVelocity(owner: "acme", repo: "widget", repository: repo, in: context)

        #expect(repo.velocityMetrics.count == 4)
        let record = try #require(repo.velocityMetrics.first { $0.periodType == "30D" })
        #expect(record.currentCount == 42)
        #expect(record.priorCount == 31)
    }

    /// Verifies that a network error leaves existing velocity records untouched.
    @Test func syncVelocitySilentlyFailsOnError() async throws {
        mockHTTP.setSuccess(json: makeResponse(d30c: 10, d30p: 8))

        let container = try makeContainer()
        let context = container.mainContext
        let repo = SavedRepository(githubId: "1", owner: "acme", name: "widget", displayName: "Widget")
        context.insert(repo)

        await makeService().syncVelocity(owner: "acme", repo: "widget", repository: repo, in: context)
        #expect(repo.velocityMetrics.count == 4)

        // Simulate a network error on the second sync
        mockHTTP.setFailure(URLError(.notConnectedToInternet))
        await makeService().syncVelocity(owner: "acme", repo: "widget", repository: repo, in: context)

        // Existing records untouched
        #expect(repo.velocityMetrics.count == 4)
        let record = try #require(repo.velocityMetrics.first { $0.periodType == "30D" })
        #expect(record.currentCount == 10)
    }

    // MARK: - VelocityComparison

    /// Verifies that a higher current count produces an `.up` trend with the correct delta.
    @Test func trendUp() {
        let c = VelocityComparison(current: 10, prior: 7)
        #expect(c.trend == .up)
        #expect(c.delta == 3)
    }

    /// Verifies that a lower current count produces a `.down` trend with the correct delta.
    @Test func trendDown() {
        let c = VelocityComparison(current: 4, prior: 9)
        #expect(c.trend == .down)
        #expect(c.delta == -5)
    }

    /// Verifies that equal counts produce a `.flat` trend with zero delta.
    @Test func trendFlat() {
        let c = VelocityComparison(current: 6, prior: 6)
        #expect(c.trend == .flat)
        #expect(c.delta == 0)
    }

    /// Verifies that `percentChange` is `nil` when the prior period had zero merges.
    @Test func percentChangeNilWhenPriorIsZero() {
        let c = VelocityComparison(current: 5, prior: 0)
        #expect(c.percentChange == nil)
    }

    /// Verifies that `percentChange` is calculated correctly when prior is non-zero.
    @Test func percentChangeCalculated() throws {
        let c = VelocityComparison(current: 15, prior: 10)
        let pct = try #require(c.percentChange)
        #expect(pct == 50.0)
    }

    // MARK: - buildDateWindows

    /// Verifies that prior windows cover the same calendar dates one year back.
    @Test func dateWindowsPriorIsSameCalendarDatesOneYearBack() throws {
        let service = makeService()
        // Use a fixed "today" so the test is deterministic
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let today = try #require(cal.date(from: DateComponents(year: 2026, month: 4, day: 6)))

        let windows = try #require(service.buildDateWindows(today: today))

        // 30D: current = 2026-03-07..2026-04-06, prior = 2025-03-07..2025-04-06
        #expect(windows.w30.current == "2026-03-07..2026-04-06")
        #expect(windows.w30.prior   == "2025-03-07..2025-04-06")

        // 7D: current = 2026-03-30..2026-04-06, prior = 2025-03-30..2025-04-06
        #expect(windows.w7.current == "2026-03-30..2026-04-06")
        #expect(windows.w7.prior   == "2025-03-30..2025-04-06")

        // 90D: current = 2026-01-06..2026-04-06, prior = 2025-01-06..2025-04-06
        #expect(windows.w90.current == "2026-01-06..2026-04-06")
        #expect(windows.w90.prior   == "2025-01-06..2025-04-06")

        // YTD: current = 2026-01-01..2026-04-06, prior = 2025-01-01..2025-04-06
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

        // YTD on Jan 1: current = 2026-01-01..2026-01-01, prior = 2025-01-01..2025-01-01
        #expect(windows.ytd.current == "2026-01-01..2026-01-01")
        #expect(windows.ytd.prior   == "2025-01-01..2025-01-01")
    }
}
