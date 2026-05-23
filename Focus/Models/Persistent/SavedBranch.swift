import Foundation
import SwiftData

// MARK: - SavedBranch

/// A GitHub branch associated with a watched repository.
///
/// `SavedBranch` is a child entity in the SwiftData graph. It is
/// cascade-deleted when its parent ``SavedRepository`` is removed.
@Model
final class SavedBranch {

    // MARK: - Properties

    /// The branch name, e.g. `"main"` or `"feature/login-redesign"`.
    var name: String = ""

    /// Whether this is the repository's default branch.
    var isDefault: Bool = false

    /// The date of the branch's most recent commit.
    var pushedAt: Date = Date()

    // MARK: - Init

    /// Creates a new saved branch record.
    ///
    /// - Parameters:
    ///   - name: The branch name, e.g. `"main"` or `"feature/login-redesign"`.
    ///   - isDefault: Whether this is the repository's default branch.
    ///   - pushedAt: The date of the branch's most recent commit.
    init(name: String, isDefault: Bool, pushedAt: Date) {
        self.name = name
        self.isDefault = isDefault
        self.pushedAt = pushedAt
    }

    // MARK: - Relationships

    /// The repository this branch belongs to.
    ///
    /// Cascade-deleted when the parent repository is removed. Inverse of ``SavedRepository/branches``.
    @Relationship var repository: SavedRepository?
}
