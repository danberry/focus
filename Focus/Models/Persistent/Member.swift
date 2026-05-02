import Foundation
import SwiftData

// MARK: - Member

/// A team member tracked in Focus, optionally linked to a GitHub account.
///
/// `Member` is a SwiftData entity that stores identity and contribution data for
/// an individual on a team. GitHub account details are optional — a member can
/// be created before their GitHub login is known and linked later.
@Model
final class Member {

    // MARK: - Properties

    /// The display name of the team member.
    var name: String

    /// The member's GitHub user ID, or `nil` if the member has not been linked to a GitHub account.
    var githubId: Int?

    /// The member's GitHub login (username), or `nil` if the member has not been linked to a GitHub account.
    var githubLogin: String?

    /// The member's assigned job title, or `nil` if no title has been assigned.
    var jobTitle: JobTitle?

    /// The total number of GitHub contributions recorded for this member during the current sync window.
    ///
    /// Defaults to `0` until a sync populates the value.
    var contributionCount: Int = 0

    /// The team this member belongs to, or `nil` if the member has not been assigned to a team.
    var team: Team?

    /// The member's direct manager, or `nil` if no manager has been assigned.
    ///
    /// Nullified when the manager is removed so direct reports survive their manager's deletion.
    var manager: Member?

    // MARK: - Init

    /// Creates a new member with an optional GitHub account link.
    ///
    /// - Parameters:
    ///   - name: The display name shown in lists and detail views.
    ///   - githubId: The stable GitHub user ID; pass `nil` to link later.
    ///   - githubLogin: The GitHub login (username); pass `nil` to link later.
    init(name: String, githubId: Int? = nil, githubLogin: String? = nil) {
        self.name = name
        self.githubId = githubId
        self.githubLogin = githubLogin
    }

    // MARK: - Relationships

    /// The members who report directly to this member.
    ///
    /// Nullified when this member is removed so direct reports are not deleted with their manager.
    /// Inverse of ``Member/manager``.
    @Relationship(deleteRule: .nullify, inverse: \Member.manager)
    var directReports: [Member] = []

    /// Per-repository contribution records for this member.
    ///
    /// Cascade-deleted when the member is removed. Inverse of ``MemberContribution/member``.
    @Relationship(deleteRule: .cascade, inverse: \MemberContribution.member)
    var contributions: [MemberContribution] = []

    /// Daily contribution snapshots for this member.
    ///
    /// Cascade-deleted when the member is removed. Inverse of ``DailyContribution/member``.
    @Relationship(deleteRule: .cascade, inverse: \DailyContribution.member)
    var dailyContributions: [DailyContribution] = []

    // MARK: - Computed

    /// The total number of contributions for this member.
    ///
    /// Returns `contributionCount` directly. Prefer this property at call sites to
    /// decouple callers from the underlying storage property.
    var totalContributions: Int { contributionCount }
}
