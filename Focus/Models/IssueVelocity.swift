import Foundation
import SwiftData

// MARK: - IssueVelocity

/// Persisted issue velocity metrics for a single time window of a repository.
///
/// `IssueVelocity` stores closed issue counts for a given ``VelocityPeriod``
/// alongside the window boundaries captured at sync time. Use the ``comparison``
/// property to derive trend direction and percentage change for display.
@Model
final class IssueVelocity {

    // MARK: - Properties

    /// The raw value of the ``VelocityPeriod`` this record represents.
    var periodType: String

    /// The number of closed issues in the current period window.
    var currentCount: Int

    /// The number of closed issues in the equivalent prior period window.
    var priorCount: Int

    /// The start of the current period window.
    var periodStart: Date

    /// The end of the current period window, captured at sync time.
    var periodEnd: Date

    /// The timestamp when this record was last fetched from GitHub.
    var fetchedAt: Date

    // MARK: - Init

    /// Creates a new issue velocity record for a given period window.
    ///
    /// - Parameters:
    ///   - periodType: The raw value of the ``VelocityPeriod`` this record represents.
    ///   - currentCount: The number of closed issues in the current period window.
    ///   - priorCount: The number of closed issues in the equivalent prior period window.
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

    /// The repository this issue velocity record belongs to.
    ///
    /// `nil` until the record is associated with a ``SavedRepository`` instance.
    var repository: SavedRepository?

    // MARK: - Computed

    /// A ``VelocityComparison`` built from the current and prior counts.
    ///
    /// Use to derive trend direction and percentage change for display.
    var comparison: VelocityComparison {
        VelocityComparison(current: currentCount, prior: priorCount)
    }
}
