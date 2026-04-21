import Foundation
import SwiftData

// MARK: - IssueVelocityService

/// Fetches and persists closed issue velocity metrics for GitHub repositories.
///
/// `IssueVelocityService` queries the GitHub GraphQL API for closed issue counts across
/// four time windows (7-day, 30-day, 90-day, year-to-date), comparing each current period
/// against the equivalent prior-year window to support trend calculations.
///
/// All network calls go through the injected ``GraphQLClient``.
struct IssueVelocityService: Sendable {

    // MARK: - Properties

    /// The GraphQL client used to execute closed issue count queries.
    private let graphQL: GraphQLClient

    // MARK: - Init

    /// Creates an issue velocity service backed by the given GraphQL client.
    ///
    /// - Parameter graphQL: The client used to execute search queries against the GitHub GraphQL API.
    init(graphQL: GraphQLClient) {
        self.graphQL = graphQL
    }

    // MARK: - Fetch (non-isolated, Sendable result)

    /// Fetches closed issue counts for all velocity periods.
    ///
    /// Returns `nil` on any network or decoding error; does not write to SwiftData.
    func fetchIssueVelocityData(owner: String, repo: String) async -> IssueVelocityFetchResult? {
        let today = Date()
        guard let windows = buildDateWindows(today: today) else { return nil }

        let base = "repo:\(owner)/\(repo) is:issue is:closed"

        let variables: [String: any Sendable] = [
            "q7c":  "\(base) closed:\(windows.w7.current)",
            "q7p":  "\(base) closed:\(windows.w7.prior)",
            "q30c": "\(base) closed:\(windows.w30.current)",
            "q30p": "\(base) closed:\(windows.w30.prior)",
            "q90c": "\(base) closed:\(windows.w90.current)",
            "q90p": "\(base) closed:\(windows.w90.prior)",
            "qYc":  "\(base) closed:\(windows.ytd.current)",
            "qYp":  "\(base) closed:\(windows.ytd.prior)"
        ]

        do {
            let response: IssueVelocityResponse = try await graphQL.execute(
                query: IssueVelocityQueries.closedIssueCounts,
                variables: variables,
                responseType: IssueVelocityResponse.self
            )
            return IssueVelocityFetchResult(
                today: today,
                windows: windows,
                w7Current:  response.w7Current.issueCount,
                w7Prior:    response.w7Prior.issueCount,
                d30Current: response.d30Current.issueCount,
                d30Prior:   response.d30Prior.issueCount,
                d90Current: response.d90Current.issueCount,
                d90Prior:   response.d90Prior.issueCount,
                ytdCurrent: response.ytdCurrent.issueCount,
                ytdPrior:   response.ytdPrior.issueCount
            )
        } catch {
            return nil
        }
    }

    // MARK: - Apply (@MainActor, writes to SwiftData)

    /// Persists fetched issue velocity metrics to SwiftData, replacing any existing records.
    ///
    /// Does nothing when `data` is `nil` (preserving any existing records).
    @MainActor
    func applyIssueVelocityData(_ data: IssueVelocityFetchResult?, to repository: SavedRepository, in context: ModelContext) {
        guard let data else { return }

        for existing in repository.issueVelocityMetrics {
            existing.repository = nil
            context.delete(existing)
        }

        let entries: [(VelocityPeriod, Date, Int, Int)] = [
            (.sevenDays,  data.windows.w7.currentStart,  data.w7Current,  data.w7Prior),
            (.thirtyDays, data.windows.w30.currentStart, data.d30Current, data.d30Prior),
            (.ninetyDays, data.windows.w90.currentStart, data.d90Current, data.d90Prior),
            (.yearToDate, data.windows.ytd.currentStart, data.ytdCurrent, data.ytdPrior)
        ]

        for (period, periodStart, current, prior) in entries {
            let velocity = IssueVelocity(
                periodType: period.rawValue,
                currentCount: current,
                priorCount: prior,
                periodStart: periodStart,
                periodEnd: data.today,
                fetchedAt: data.today
            )
            velocity.repository = repository
            context.insert(velocity)
        }

        try? context.save()
    }

    // MARK: - Sync (fetch + apply, used by tests and legacy call sites)

    /// Fetches closed issue counts for all velocity periods and persists them to SwiftData.
    ///
    /// Performs a single batched GraphQL query covering eight search windows (four periods × current/prior).
    /// On success, replaces any existing ``IssueVelocity`` records for the repository with fresh data.
    /// On failure, exits silently — any previously persisted data is left intact.
    ///
    /// - Parameters:
    ///   - owner: The repository owner login (user or organization).
    ///   - repo: The repository name.
    ///   - repository: The SwiftData object to associate new issue velocity records with.
    ///   - context: The SwiftData model context used to insert and delete records.
    @MainActor
    func syncIssueVelocity(owner: String, repo: String, repository: SavedRepository, in context: ModelContext) async {
        let data = await fetchIssueVelocityData(owner: owner, repo: repo)
        applyIssueVelocityData(data, to: repository, in: context)
    }

    // MARK: - Date Windows

    /// A date range window expressed as GitHub search-compatible strings and a concrete start `Date`.
    struct DateWindow: Sendable {
        /// A GitHub search-compatible date range string in `YYYY-MM-DD..YYYY-MM-DD` format for the current period.
        let current: String
        /// A GitHub search-compatible date range string for the equivalent prior-year period.
        let prior: String
        /// The start `Date` of the current window, used when persisting the record to SwiftData.
        let currentStart: Date
    }

    /// The complete set of date windows for all four velocity periods.
    struct AllDateWindows: Sendable {
        /// The 7-day rolling window.
        let w7: DateWindow
        /// The 30-day rolling window.
        let w30: DateWindow
        /// The 90-day rolling window.
        let w90: DateWindow
        /// The year-to-date window, from January 1 of the current year through today.
        let ytd: DateWindow
    }

    /// Builds search-compatible date range strings for all four velocity periods.
    ///
    /// Each period produces a current window and a prior-year window covering the same calendar dates
    /// one year back. Returns `nil` if any required date arithmetic fails.
    ///
    /// - Parameter today: The reference date from which all windows are calculated.
    func buildDateWindows(today: Date) -> AllDateWindows? {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone(identifier: "UTC")

        func rangeString(from start: Date, to end: Date) -> String {
            "\(fmt.string(from: start))..\(fmt.string(from: end))"
        }

        guard
            let todayPrior = cal.date(byAdding: .year, value: -1, to: today),
            let start7      = cal.date(byAdding: .day,  value: -7,  to: today),
            let start7Prior = cal.date(byAdding: .year, value: -1,  to: start7),
            let start30     = cal.date(byAdding: .day,  value: -30, to: today),
            let start30Prior = cal.date(byAdding: .year, value: -1, to: start30),
            let start90     = cal.date(byAdding: .day,  value: -90, to: today),
            let start90Prior = cal.date(byAdding: .year, value: -1, to: start90)
        else { return nil }

        let yearComponents = DateComponents(year: cal.component(.year, from: today), month: 1, day: 1)
        guard
            let yearStart      = cal.date(from: yearComponents),
            let yearStartPrior = cal.date(byAdding: .year, value: -1, to: yearStart)
        else { return nil }

        return AllDateWindows(
            w7: DateWindow(
                current: rangeString(from: start7,       to: today),
                prior:   rangeString(from: start7Prior,  to: todayPrior),
                currentStart: start7
            ),
            w30: DateWindow(
                current: rangeString(from: start30,      to: today),
                prior:   rangeString(from: start30Prior, to: todayPrior),
                currentStart: start30
            ),
            w90: DateWindow(
                current: rangeString(from: start90,      to: today),
                prior:   rangeString(from: start90Prior, to: todayPrior),
                currentStart: start90
            ),
            ytd: DateWindow(
                current: rangeString(from: yearStart,      to: today),
                prior:   rangeString(from: yearStartPrior, to: todayPrior),
                currentStart: yearStart
            )
        )
    }
}

// MARK: - IssueVelocityFetchResult

/// The fetched issue velocity data for a single repository, ready to be written to SwiftData.
struct IssueVelocityFetchResult: Sendable {
    /// The reference date used as the period end and fetch timestamp.
    let today: Date
    /// The date windows used to compute each period's start date.
    let windows: IssueVelocityService.AllDateWindows
    let w7Current: Int
    let w7Prior: Int
    let d30Current: Int
    let d30Prior: Int
    let d90Current: Int
    let d90Prior: Int
    let ytdCurrent: Int
    let ytdPrior: Int
}

// MARK: - API Response Types

/// A single search result count returned by the GitHub GraphQL search API.
private struct IssueSearchCount: Decodable, Sendable {
    /// The number of issues matching the search query.
    let issueCount: Int
}

/// The batched GraphQL response containing closed issue counts for all eight velocity search windows.
private struct IssueVelocityResponse: Decodable, Sendable {
    let w7Current: IssueSearchCount
    let w7Prior: IssueSearchCount
    let d30Current: IssueSearchCount
    let d30Prior: IssueSearchCount
    let d90Current: IssueSearchCount
    let d90Prior: IssueSearchCount
    let ytdCurrent: IssueSearchCount
    let ytdPrior: IssueSearchCount
}
