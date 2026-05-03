import Foundation
import SwiftData

// MARK: - JobTitle

/// A job title that can be assigned to team members and grouped under a discipline.
///
/// `JobTitle` is a SwiftData entity that belongs to the Settings graph. It is
/// optionally associated with a ``Discipline``; the discipline's `jobTitles`
/// relationship cascade-deletes its members when the discipline is removed.
@Model
final class JobTitle {

    // MARK: - Properties

    /// The display name of the job title.
    var name: String = ""

    // MARK: - Init

    /// Creates a new job title.
    ///
    /// - Parameter name: The display name shown in lists and pickers.
    init(name: String) {
        self.name = name
    }

    // MARK: - Relationships

    /// The discipline this job title belongs to, or `nil` if unassigned.
    ///
    /// Inverse of ``Discipline/jobTitles``. Set to `nil` until the job title is
    /// placed under a discipline.
    var discipline: Discipline?

    /// The members assigned to this job title.
    ///
    /// Nullified when this job title is deleted so members retain their record
    /// but lose the title assignment. Inverse of ``Member/jobTitle``.
    @Relationship(deleteRule: .nullify, inverse: \Member.jobTitle)
    var members: [Member] = []
}
