import Foundation
import SwiftData

// MARK: - VelocityService

struct VelocityService: Sendable {
    private let graphQL: GraphQLClient

    init(graphQL: GraphQLClient) {
        self.graphQL = graphQL
    }

    // MARK: - Sync

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

    struct DateWindow {
        let current: String     // "YYYY-MM-DD..YYYY-MM-DD" for the current period
        let prior: String       // same calendar dates one year back
        let currentStart: Date  // start Date of the current window (for storage)
    }

    struct AllDateWindows {
        let w7: DateWindow
        let w30: DateWindow
        let w90: DateWindow
        let ytd: DateWindow
    }

    /// Builds the 8 search-compatible date range strings for all period types.
    /// Prior period = same calendar dates one year back.
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

// MARK: - Response Types

private struct SearchCount: Decodable, Sendable {
    let issueCount: Int
}

private struct VelocityResponse: Decodable, Sendable {
    let w7Current: SearchCount
    let w7Prior: SearchCount
    let d30Current: SearchCount
    let d30Prior: SearchCount
    let d90Current: SearchCount
    let d90Prior: SearchCount
    let ytdCurrent: SearchCount
    let ytdPrior: SearchCount
}
