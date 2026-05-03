import Foundation
import SwiftData

// MARK: - Codeowner

/// A code owner entry parsed from a repository's CODEOWNERS file.
///
/// `Codeowner` represents a single ownership rule, mapping a GitHub user or team
/// handle to an optional path pattern. When `pathPattern` is `nil`, the owner
/// applies to the entire repository.
@Model
final class Codeowner {

    // MARK: - Properties

    /// The GitHub login or team slug for this owner (e.g., `"octocat"` or `"org/team-name"`).
    var handle: String = ""

    /// Whether this owner refers to a GitHub team rather than an individual user.
    ///
    /// Derived from `handle` at init time: `true` when the handle contains a `/`.
    var isTeam: Bool = false

    /// The CODEOWNERS path pattern this rule applies to, or `nil` if it applies to the whole repository.
    var pathPattern: String?

    // MARK: - Init

    /// Creates a new code owner entry.
    ///
    /// - Parameters:
    ///   - handle: The GitHub login or team slug. A `/` in the handle indicates a team.
    ///   - pathPattern: The path pattern from the CODEOWNERS file. Pass `nil` for a catch-all rule.
    init(handle: String, pathPattern: String? = nil) {
        self.handle = handle
        self.isTeam = handle.contains("/")
        self.pathPattern = pathPattern
    }

    // MARK: - Relationships

    /// The repository this code owner belongs to.
    ///
    /// Inverse of ``SavedRepository/codeOwners``.
    var repository: SavedRepository?
}
