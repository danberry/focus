import Foundation
import SwiftData

// MARK: - RepositoryCommitDay

/// A recorded commit count for a repository on a specific calendar date.
///
/// `RepositoryCommitDay` is a leaf entity in the SwiftData graph. It is
/// cascade-deleted when its associated ``SavedRepository`` is removed via the
/// `SavedRepository.commitActivity` relationship.
///
/// Records are sourced from the GitHub Stats API
/// (`/repos/{owner}/{repo}/stats/commit_activity`) and represent the number of
/// commits that landed on a given day. Days with zero commits are not stored —
/// absence of a record for a date implies a count of zero.
@Model
final class RepositoryCommitDay {

    // MARK: - Properties

    /// The calendar date this commit count represents (midnight UTC).
    var date: Date = Date()

    /// The number of commits recorded for this date.
    var commitCount: Int = 0

    // MARK: - Init

    /// Creates a new commit-day record.
    ///
    /// - Parameters:
    ///   - date: The calendar date this commit count represents.
    ///   - commitCount: The number of commits recorded for this date.
    init(date: Date, commitCount: Int) {
        self.date = date
        self.commitCount = commitCount
    }

    // MARK: - Relationships

    /// The repository whose commit activity this record belongs to.
    ///
    /// Inverse of ``SavedRepository/commitActivity``.
    @Relationship var repository: SavedRepository?
}
