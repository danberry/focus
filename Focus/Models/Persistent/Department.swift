import Foundation
import SwiftData

// MARK: - Department

/// A department grouping that sits between an organization and its teams.
///
/// `Department` is an optional middle layer in the organizational hierarchy. A
/// ``SavedOrganization`` can own zero or more departments, and each department
/// can own zero or more ``Team`` records. Departments are nullified (not
/// cascade-deleted) when removed, so their teams survive and simply lose their
/// department assignment.
@Model
final class Department {

    // MARK: - Properties

    /// The display name of the department (e.g., "Platform", "Infrastructure").
    var name: String = ""

    /// A human-readable description of the department's purpose, or `nil` if none is set.
    var departmentDescription: String?

    // MARK: - Init

    /// Creates a new department.
    ///
    /// - Parameters:
    ///   - name: The display name shown in lists and detail views.
    ///   - departmentDescription: A human-readable description of the department's purpose; defaults to `nil`.
    init(name: String, departmentDescription: String? = nil) {
        self.name = name
        self.departmentDescription = departmentDescription
    }

    // MARK: - Relationships

    /// The organization this department belongs to, or `nil` if the department has not been assigned to an organization.
    ///
    /// Nullified when the organization is removed. Inverse of ``SavedOrganization/departments``.
    var organization: SavedOrganization?

    /// The teams belonging to this department.
    ///
    /// Nullified when the department is removed. Inverse of ``Team/department``.
    @Relationship(deleteRule: .nullify, inverse: \Team.department)
    var teams: [Team]?
}
