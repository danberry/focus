import Foundation
import SwiftData

// MARK: - SavedOrganization

/// A GitHub organization that has been saved to the user's watch list.
///
/// `SavedOrganization` is persisted in the SwiftData store and drives the
/// organization-scoped views in the Settings tab. Each instance maps to a
/// single GitHub organization identified by its stable node ID.
@Model
final class SavedOrganization {

    // MARK: - Properties

    /// The stable GitHub node ID for the organization.
    var githubId: String

    /// The organization's login handle (e.g. `"apple"`).
    var login: String

    /// The organization's display name, or `nil` if GitHub reports none.
    var name: String?

    /// The URL string for the organization's avatar image, or `nil` if unavailable.
    var avatarUrl: String?

    /// The organization's public description, or `nil` if none is set.
    var organizationDescription: String?

    /// The date the user added this organization to their watch list.
    var addedAt: Date

    // MARK: - Init

    /// Creates a new saved organization.
    ///
    /// - Parameters:
    ///   - githubId: The stable GitHub node ID for the organization.
    ///   - login: The organization's login handle.
    ///   - name: The organization's display name; defaults to `nil`.
    ///   - avatarUrl: The URL string for the organization's avatar; defaults to `nil`.
    ///   - organizationDescription: The organization's public description; defaults to `nil`.
    init(githubId: String, login: String, name: String? = nil, avatarUrl: String? = nil, organizationDescription: String? = nil) {
        self.githubId = githubId
        self.login = login
        self.name = name
        self.avatarUrl = avatarUrl
        self.organizationDescription = organizationDescription
        self.addedAt = Date()
    }

    // MARK: - Relationships

    /// The departments belonging to this organization.
    ///
    /// Cascade-deleted when the organization is removed. Inverse of ``Department/organization``.
    @Relationship(deleteRule: .cascade, inverse: \Department.organization)
    var departments: [Department] = []

    /// The teams directly belonging to this organization, without a department grouping.
    ///
    /// Nullified when the organization is removed. Inverse of ``Team/organization``.
    @Relationship(deleteRule: .nullify, inverse: \Team.organization)
    var teams: [Team] = []
}
