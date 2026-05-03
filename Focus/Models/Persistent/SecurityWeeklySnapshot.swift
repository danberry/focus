import Foundation
import SwiftData

// MARK: - SecurityWeeklySnapshot

/// A weekly aggregate of security alert totals, persisted so Tier 2 trend rules
/// can compare this week's posture against prior weeks.
///
/// One record is written per briefing week. On re-generation the existing record
/// for the same week is updated in place rather than duplicated.
@Model
final class SecurityWeeklySnapshot {

    // MARK: - Properties

    /// The Monday that begins the briefing week (midnight, user's locale).
    var weekStart: Date = Date()

    /// Total open alerts across all scanners at week end.
    var totalOpen: Int = 0

    /// Total open critical Dependabot alerts at week end.
    var totalCritical: Int = 0

    /// Alerts with `createdAt` inside the week interval that are still open.
    ///
    /// This is an approximation of intake — alerts opened and then resolved within
    /// the same week are not counted here. Tier 3 will add a more accurate figure
    /// once the dismissed-alert REST fetch lands.
    var opened: Int = 0

    /// Alerts dismissed or fixed during the week.
    ///
    /// Stubbed as `0` until the Tier 3 closure API fetch ships.
    var closed: Int = 0

    /// JSON-encoded `[String: Int]` mapping repo display name → open critical count.
    ///
    /// Stored as `Data` because SwiftData does not persist `Dictionary` values directly.
    var repoCriticalCountsJSON: Data?

    // MARK: - Derived

    /// Decodes ``repoCriticalCountsJSON`` into a Swift dictionary.
    var repoCriticalCounts: [String: Int] {
        guard let data = repoCriticalCountsJSON else { return [:] }
        return (try? JSONDecoder().decode([String: Int].self, from: data)) ?? [:]
    }

    // MARK: - Init

    /// Creates a new snapshot for the given week.
    ///
    /// - Parameters:
    ///   - weekStart: The Monday midnight that opens the briefing week.
    ///   - totalOpen: Total open alerts across all scanners.
    ///   - totalCritical: Total open critical Dependabot alerts.
    ///   - opened: Alerts created during the week that are still open.
    ///   - closed: Alerts resolved during the week (default `0` until Tier 3).
    ///   - repoCriticalCounts: Per-repo critical counts keyed by display name.
    init(
        weekStart: Date,
        totalOpen: Int,
        totalCritical: Int,
        opened: Int,
        closed: Int = 0,
        repoCriticalCounts: [String: Int] = [:]
    ) {
        self.weekStart = weekStart
        self.totalOpen = totalOpen
        self.totalCritical = totalCritical
        self.opened = opened
        self.closed = closed
        self.repoCriticalCountsJSON = try? JSONEncoder().encode(repoCriticalCounts)
    }
}
