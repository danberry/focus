import Foundation
import SwiftData

// MARK: - Team

/// A GitHub team persisted to the SwiftData store.
///
/// `Team` is a graph root for its members. All ``Member`` records
/// cascade-delete when the team is removed.
@Model
final class Team {

    // MARK: - Properties

    /// The team's display name as returned by the GitHub API.
    var name: String

    /// A human-readable description of the team's purpose.
    var teamDescription: String

    // MARK: - Init

    /// Creates a new team.
    ///
    /// - Parameters:
    ///   - name: The team's display name.
    ///   - teamDescription: A human-readable description of the team's purpose.
    init(name: String, teamDescription: String) {
        self.name = name
        self.teamDescription = teamDescription
    }

    // MARK: - Relationships

    /// The members belonging to this team.
    ///
    /// Cascade-deleted when the team is removed. Inverse of ``Member/team``.
    @Relationship(deleteRule: .cascade, inverse: \Member.team)
    var members: [Member] = []
}
