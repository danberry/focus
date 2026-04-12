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
    var name: String

    // MARK: - Init

    /// Creates a new discipline with the given name.
    ///
    /// - Parameter name: The display name shown in lists and detail views.
    init(name: String) {
        self.name = name
    }

    // MARK: - Relationships

    /// Job titles that belong to this discipline.
    ///
    /// Cascade-deleted when the discipline is removed.
    @Relationship(deleteRule: .cascade) var jobTitles: [JobTitle] = []
}
