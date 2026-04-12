import Foundation
import SwiftData

// MARK: - MemberContribution

/// Aggregated contribution activity for a team member over a specific time period.
///
/// `MemberContribution` is persisted as part of the SwiftData graph and is
/// cascade-deleted when its owning ``Member`` is removed.
@Model
final class MemberContribution {

    // MARK: - Properties

    /// The number of commits authored during the period.
    var commits: Int

    /// The number of pull requests opened during the period.
    var pullRequests: Int

    /// The number of pull request reviews submitted during the period.
    var reviews: Int

    /// The number of issues opened during the period.
    var issues: Int

    /// The start of the contribution period (inclusive).
    var periodStart: Date

    /// The end of the contribution period (inclusive).
    var periodEnd: Date

    /// The date and time this record was last fetched from the GitHub API.
    var fetchedAt: Date

    // MARK: - Init

    /// Creates a new member contribution record.
    ///
    /// - Parameters:
    ///   - commits: The number of commits authored during the period.
    ///   - pullRequests: The number of pull requests opened during the period.
    ///   - reviews: The number of pull request reviews submitted during the period.
    ///   - issues: The number of issues opened during the period.
    ///   - periodStart: The start of the contribution period (inclusive).
    ///   - periodEnd: The end of the contribution period (inclusive).
    ///   - fetchedAt: The date and time this record was fetched from the GitHub API.
    init(
        commits: Int,
        pullRequests: Int,
        reviews: Int,
        issues: Int,
        periodStart: Date,
        periodEnd: Date,
        fetchedAt: Date
    ) {
        self.commits = commits
        self.pullRequests = pullRequests
        self.reviews = reviews
        self.issues = issues
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.fetchedAt = fetchedAt
    }

    // MARK: - Relationships

    /// The member this contribution record belongs to, or `nil` if not yet assigned.
    ///
    /// Inverse of ``Member/contributions``. Cascade-deleted when the owning member is removed.
    var member: Member?
}
