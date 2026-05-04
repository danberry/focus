import Foundation
import SwiftData

// MARK: - DailyContribution

/// A recorded count of GitHub contributions for a team member on a specific date.
///
/// `DailyContribution` is a leaf entity in the SwiftData graph. It is
/// cascade-deleted when its associated ``Member`` is removed via the
/// `Member.dailyContributions` relationship.
@Model
final class DailyContribution {

    // MARK: - Properties

    /// The calendar date this contribution count represents.
    var date: Date = Date()

    /// The number of contributions recorded for this date.
    var count: Int = 0

    // MARK: - Init

    /// Creates a new daily contribution record.
    ///
    /// - Parameters:
    ///   - date: The calendar date this contribution count represents.
    ///   - count: The number of contributions recorded for this date.
    init(date: Date, count: Int) {
        self.date = date
        self.count = count
    }

    // MARK: - Relationships

    /// The team member who made these contributions.
    ///
    /// Inverse of ``Member/dailyContributions``. Set to `nil` only when the
    /// contribution has not yet been associated with a member.
    @Relationship var member: Member?
}
