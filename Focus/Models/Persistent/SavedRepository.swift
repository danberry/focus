import Foundation
import SwiftData

// MARK: - SavedRepository

/// A GitHub repository that has been saved to the user's watch list.
///
/// `SavedRepository` is the root entity in the SwiftData graph. All alert
/// details, velocity metrics, pull requests, and code owners cascade-delete
/// when the repository is removed.
@Model
final class SavedRepository {

    // MARK: - Properties

    /// The stable GitHub node ID for the repository.
    var githubId: String = ""

    /// The repository owner's login (user or organization).
    var owner: String = ""

    /// The repository name.
    var name: String = ""

    /// The user-facing label shown in lists and navigation titles.
    var displayName: String = ""

    /// The repository's primary programming language, or `nil` if GitHub reports none.
    var primaryLanguage: String?

    /// The login of the GitHub organization that owns this repository, or `nil` if the owner is a user account.
    ///
    /// Stored as a string rather than a relationship to ``SavedOrganization`` because the
    /// repository owner may not be a watched organization.
    var organizationLogin: String?

    /// When `true`, the repository is in maintenance mode and is excluded from low-activity
    /// performance alerts in the weekly briefing.
    var isInMaintenance: Bool = false

    // MARK: - Init

    /// Creates a new saved repository.
    ///
    /// - Parameters:
    ///   - githubId: The stable GitHub node ID for the repository.
    ///   - owner: The repository owner's login (user or organization).
    ///   - name: The repository name.
    ///   - displayName: The user-facing label shown in lists and navigation titles.
    ///   - primaryLanguage: The repository's primary programming language; defaults to `nil`.
    init(
        githubId: String,
        owner: String,
        name: String,
        displayName: String,
        primaryLanguage: String? = nil
    ) {
        self.githubId = githubId
        self.owner = owner
        self.name = name
        self.displayName = displayName
        self.primaryLanguage = primaryLanguage
    }

    // MARK: - Relationships

    /// Dependabot alerts for this repository, including dismissed, fixed, and auto-dismissed.
    ///
    /// Cascade-deleted when the repository is removed. Inverse of ``DependabotAlert/repository``.
    @Relationship(deleteRule: .cascade, inverse: \DependabotAlert.repository)
    var dependabotAlertDetails: [DependabotAlert]?

    /// Open code scanning alerts for this repository.
    ///
    /// Cascade-deleted when the repository is removed. Inverse of ``CodeScanningAlert/repository``.
    @Relationship(deleteRule: .cascade, inverse: \CodeScanningAlert.repository)
    var codeScanningAlertDetails: [CodeScanningAlert]?

    /// Secret scanning alerts for this repository, including resolved ones.
    ///
    /// Cascade-deleted when the repository is removed. Inverse of ``SecretScanningAlert/repository``.
    @Relationship(deleteRule: .cascade, inverse: \SecretScanningAlert.repository)
    var secretScanningAlertDetails: [SecretScanningAlert]?

    /// Code owners assigned to this repository.
    ///
    /// Cascade-deleted when the repository is removed. Inverse of ``Codeowner/repository``.
    @Relationship(deleteRule: .cascade, inverse: \Codeowner.repository)
    var codeowners: [Codeowner]?

    /// Velocity metrics for this repository.
    ///
    /// Cascade-deleted when the repository is removed. Inverse of ``RepositoryVelocity/repository``.
    @Relationship(deleteRule: .cascade, inverse: \RepositoryVelocity.repository)
    var velocityMetrics: [RepositoryVelocity]?

    /// Open pull requests for this repository.
    ///
    /// Cascade-deleted when the repository is removed. Inverse of ``OpenPullRequest/repository``.
    @Relationship(deleteRule: .cascade, inverse: \OpenPullRequest.repository)
    var openPullRequests: [OpenPullRequest]?

    /// Daily commit counts for this repository, sourced from the GitHub Stats API.
    ///
    /// Cascade-deleted when the repository is removed. Inverse of ``RepositoryCommitDay/repository``.
    /// Days with zero commits are not stored — a missing record implies a count of zero.
    @Relationship(deleteRule: .cascade, inverse: \RepositoryCommitDay.repository)
    var commitActivity: [RepositoryCommitDay]?

    /// The most recent releases for this repository.
    ///
    /// Cascade-deleted when the repository is removed. Inverse of ``SavedRelease/repository``.
    @Relationship(deleteRule: .cascade, inverse: \SavedRelease.repository)
    var releases: [SavedRelease]?

    /// The team that owns this repository, or `nil` if no team has been assigned.
    ///
    /// Nullified when the team is removed. Inverse of ``Team/repositories``.
    @Relationship var team: Team?

    // MARK: - Computed

    /// The number of open Dependabot alerts, derived from ``dependabotAlertDetails``.
    ///
    /// The relationship may include dismissed, fixed, and auto-dismissed alerts; only `"open"` ones count.
    var dependabotAlerts: Int { (dependabotAlertDetails ?? []).filter { $0.state == "open" }.count }

    /// The number of open code scanning alerts, derived from ``codeScanningAlertDetails``.
    ///
    /// The relationship may include dismissed and fixed alerts; only `"open"` ones count.
    var codeScanningAlerts: Int { (codeScanningAlertDetails ?? []).filter { $0.state == "open" }.count }

    /// The number of open secret scanning alerts, derived from ``secretScanningAlertDetails``.
    ///
    /// The relationship may include resolved alerts; only `"open"` ones count.
    var secretScanningAlerts: Int { (secretScanningAlertDetails ?? []).filter { $0.state == "open" }.count }

    /// The sum of all three security alert type counts.
    ///
    /// Use for badge display. Prefer individual alert count properties when the
    /// breakdown by type matters.
    var totalSecurityAlerts: Int {
        dependabotAlerts + codeScanningAlerts + secretScanningAlerts
    }
}
