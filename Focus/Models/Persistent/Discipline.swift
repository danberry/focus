import Foundation
import SwiftData

// MARK: - Discipline

/// A discipline category used to group job titles within an organization.
///
/// `Discipline` is a top-level classification in the settings graph. Each discipline
/// owns a collection of ``JobTitle`` records; removing a discipline cascade-deletes
/// all of its associated job titles.
@Model
final class Discipline {

    // MARK: - Properties

    /// The display name of the discipline (e.g., "Engineering", "Design").
    var name: String = ""

    /// Whether members in this discipline are expected to have GitHub activity.
    ///
    /// Set to `false` for disciplines like Design or Product Management whose
    /// practitioners don't commit code, so they are excluded from inactivity
    /// flagging in the Focus Briefing.
    var tracksGitHubActivity: Bool = true

    // MARK: - Init

    /// Creates a new discipline with the given name.
    ///
    /// - Parameters:
    ///   - name: The display name shown in lists and detail views.
    ///   - tracksGitHubActivity: Whether members are expected to have GitHub contributions.
    init(name: String, tracksGitHubActivity: Bool = true) {
        self.name = name
        self.tracksGitHubActivity = tracksGitHubActivity
    }

    // MARK: - Relationships

    /// Job titles that belong to this discipline.
    ///
    /// Cascade-deleted when the discipline is removed.
    @Relationship(deleteRule: .cascade, inverse: \JobTitle.discipline) var jobTitles: [JobTitle]?
}
