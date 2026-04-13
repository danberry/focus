import Foundation
import SwiftData

// MARK: - VelocityService

/// Fetches and persists merged pull request velocity metrics for GitHub repositories.
///
/// `VelocityService` queries the GitHub GraphQL API for merged PR counts across four
/// time windows (7-day, 30-day, 90-day, year-to-date), comparing each current period
/// against the equivalent prior-year window to support trend calculations.
///
/// All network calls go through the injected ``GraphQLClient``.
struct VelocityService: Sendable {

    // MARK: - Properties

    /// The GraphQL client used to execute merged PR count queries.
    private let graphQL: GraphQLClient

    // MARK: - Init

    /// Creates a velocity service backed by the given GraphQL client.
    ///
    /// - Parameter graphQL: The client used to execute search queries against the GitHub GraphQL API.
    init(graphQL: GraphQLClient) {
        self.graphQL = graphQL
    }

    // MARK: - Sync

    /// Fetches merged PR counts for all velocity periods and persists them to SwiftData.
    ///
    /// Performs a single batched GraphQL query covering eight search windows (four periods × current/prior).
    /// On success, replaces any existing ``RepositoryVelocity`` records for the repository with fresh data.
    /// On failure, exits silently — any previously persisted data is left intact.
    ///
    /// - Parameters:
    ///   - owner: The repository owner login (user or organization).
    ///   - repo: The repository name.
    ///   - repository: The SwiftData object to associate new velocity records with.
    ///   - context: The SwiftData model context used to insert and delete records.
    @MainActor
    func syncVelocity(owner: String, repo: String, repository: SavedRepository, in context: ModelContext) async {
        let today = Date()
        guard let windows = buildDateWindows(today: today) else { return }

        let base = "repo:\(owner)/\(repo) is:pr is:merged"

        let variables: [String: any Sendable] = [
            "q7c":  "\(base) merged:\(windows.w7.current)",
            "q7p":  "\(base) merged:\(windows.w7.prior)",
            "q30c": "\(base) merged:\(windows.w30.current)",
            "q30p": "\(base) merged:\(windows.w30.prior)",
            "q90c": "\(base) merged:\(windows.w90.current)",
            "q90p": "\(base) merged:\(windows.w90.prior)",
            "qYc":  "\(base) merged:\(windows.ytd.current)",
            "qYp":  "\(base) merged:\(windows.ytd.prior)"
        ]

        do {
            let response: VelocityResponse = try await graphQL.execute(
                query: VelocityQueries.mergedPRCounts,
                variables: variables,
                responseType: VelocityResponse.self
            )

            // Full-replace sync: remove existing velocity records for this repository.
            for existing in repository.velocityMetrics {
                existing.repository = nil
                context.delete(existing)
            }

            let entries: [(VelocityPeriod, DateWindow, Int, Int)] = [
                (.sevenDays,   windows.w7,  response.w7Current.issueCount,  response.w7Prior.issueCount),
                (.thirtyDays,  windows.w30, response.d30Current.issueCount, response.d30Prior.issueCount),
                (.ninetyDays,  windows.w90, response.d90Current.issueCount, response.d90Prior.issueCount),
                (.yearToDate,  windows.ytd, response.ytdCurrent.issueCount, response.ytdPrior.issueCount)
            ]

            for (period, window, current, prior) in entries {
                let velocity = RepositoryVelocity(
                    periodType: period.rawValue,
                    currentCount: current,
                    priorCount: prior,
                    periodStart: window.currentStart,
                    periodEnd: today,
                    fetchedAt: today
                )
                velocity.repository = repository
                context.insert(velocity)
            }

            try? context.save()
        } catch {
            // Silently fail — keeps any existing data intact
        }
    }

    // MARK: - Date Windows

    /// A date range window expressed as GitHub search-compatible strings and a concrete start `Date`.
    struct DateWindow {
        /// A GitHub search-compatible date range string in `YYYY-MM-DD..YYYY-MM-DD` format for the current period.
        let current: String
        /// A GitHub search-compatible date range string for the equivalent prior-year period.
        let prior: String
        /// The start `Date` of the current window, used when persisting the record to SwiftData.
        let currentStart: Date
    }

    /// The complete set of date windows for all four velocity periods.
    struct AllDateWindows {
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
    /// - Returns: An ``AllDateWindows`` containing eight date range strings, or `nil` if date construction fails.
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

        // YTD: Jan 1 this year → today; Jan 1 last year → same day last year
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

// MARK: - API Response Types

/// A single search result count returned by the GitHub GraphQL search API.
private struct SearchCount: Decodable, Sendable {
    /// The number of pull requests matching the search query.
    let issueCount: Int
}

/// The batched GraphQL response containing merged PR counts for all eight velocity search windows.
private struct VelocityResponse: Decodable, Sendable {
    /// The merged PR count for the current 7-day window.
    let w7Current: SearchCount
    /// The merged PR count for the prior-year 7-day window.
    let w7Prior: SearchCount
    /// The merged PR count for the current 30-day window.
    let d30Current: SearchCount
    /// The merged PR count for the prior-year 30-day window.
    let d30Prior: SearchCount
    /// The merged PR count for the current 90-day window.
    let d90Current: SearchCount
    /// The merged PR count for the prior-year 90-day window.
    let d90Prior: SearchCount
    /// The merged PR count for the current year-to-date window.
    let ytdCurrent: SearchCount
    /// The merged PR count for the prior-year year-to-date window.
    let ytdPrior: SearchCount
}
