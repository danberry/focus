import Foundation
import SwiftData

// MARK: - VelocityPeriod

/// A time window used to bucket merged PR counts for velocity calculations.
enum VelocityPeriod: String, CaseIterable {
    /// The trailing seven-day window.
    case sevenDays = "7D"
    /// The trailing thirty-day window.
    case thirtyDays = "30D"
    /// The trailing ninety-day window.
    case ninetyDays = "90D"
    /// The window from the start of the current calendar year to today.
    case yearToDate = "YTD"
}

// MARK: - VelocityComparison

/// A comparison of merged PR counts between the current and prior period of equal length.
struct VelocityComparison {

    // MARK: - Properties

    /// The merged PR count for the current period.
    let current: Int

    /// The merged PR count for the prior period of equal length.
    let prior: Int

    /// The direction of change between two velocity periods.
    enum Trend {
        /// Merged PR count increased relative to the prior period.
        case up
        /// Merged PR count decreased relative to the prior period.
        case down
        /// Merged PR count was unchanged relative to the prior period.
        case flat
    }

    // MARK: - Computed

    /// The difference between the current and prior merged PR counts.
    var delta: Int { current - prior }

    /// The percentage change from the prior period to the current period, or `nil` if the prior count is zero.
    var percentChange: Double? {
        guard prior > 0 else { return nil }
        return Double(delta) / Double(prior) * 100.0
    }

    /// The trend direction derived from the delta between current and prior counts.
    var trend: Trend {
        if delta > 0 { return .up }
        if delta < 0 { return .down }
        return .flat
    }
}

// MARK: - RepositoryVelocity

/// Persisted velocity metrics for a single time window of a repository.
///
/// `RepositoryVelocity` stores merged PR counts for a given ``VelocityPeriod``
/// alongside the window boundaries captured at sync time. Use the ``comparison``
/// property to derive trend direction and percentage change for display.
@Model
final class RepositoryVelocity {

    // MARK: - Properties

    /// The raw value of the ``VelocityPeriod`` this record represents.
    var periodType: String = ""

    /// The number of merged PRs in the current period window.
    var currentCount: Int = 0

    /// The number of merged PRs in the equivalent prior period window.
    var priorCount: Int = 0

    /// The start of the current period window.
    var periodStart: Date = Date()

    /// The end of the current period window, captured at sync time.
    var periodEnd: Date = Date()

    /// The timestamp when this record was last fetched from GitHub.
    var fetchedAt: Date = Date()

    // MARK: - Init

    /// Creates a new velocity record for a given period window.
    ///
    /// - Parameters:
    ///   - periodType: The raw value of the ``VelocityPeriod`` this record represents.
    ///   - currentCount: The number of merged PRs in the current period window.
    ///   - priorCount: The number of merged PRs in the equivalent prior period window.
    ///   - periodStart: The start of the current period window.
    ///   - periodEnd: The end of the current period window.
    ///   - fetchedAt: The timestamp when this record was last fetched from GitHub.
    init(
        periodType: String,
        currentCount: Int,
        priorCount: Int,
        periodStart: Date,
        periodEnd: Date,
        fetchedAt: Date
    ) {
        self.periodType = periodType
        self.currentCount = currentCount
        self.priorCount = priorCount
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.fetchedAt = fetchedAt
    }

    // MARK: - Relationships

    /// The repository this velocity record belongs to.
    ///
    /// `nil` until the record is associated with a ``SavedRepository`` instance.
    @Relationship var repository: SavedRepository?

    // MARK: - Computed

    /// A ``VelocityComparison`` built from the current and prior counts.
    ///
    /// Use to derive trend direction and percentage change for display.
    var comparison: VelocityComparison {
        VelocityComparison(current: currentCount, prior: priorCount)
    }
}
