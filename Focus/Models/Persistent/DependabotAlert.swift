import Foundation
import SwiftData

// MARK: - DependabotAlert

/// A Dependabot security alert for a vulnerable dependency in a GitHub repository.
///
/// `DependabotAlert` stores the full advisory detail synced from the GitHub REST API.
/// It is the inverse entity of `SavedRepository`'s `dependabotAlertDetails` relationship
/// and is cascade-deleted when the parent repository is removed.
///
/// The relationship stores alerts of all states (open, dismissed, fixed, auto_dismissed);
/// only `"open"` ones count towards ``SavedRepository/dependabotAlerts``.
@Model
final class DependabotAlert {

    // MARK: - Properties

    /// The GitHub-assigned number identifying this alert within the repository.
    var alertNumber: Int = 0

    /// The name of the vulnerable package.
    var packageName: String = ""

    /// The severity level of the alert (e.g., `"critical"`, `"high"`, `"medium"`, `"low"`).
    var severity: String = ""

    /// The version in which the vulnerability is fixed, or `nil` if no fix is available.
    var fixVersion: String?

    /// The date and time the alert was opened.
    var createdAt: Date = Date()

    /// A brief description of the vulnerability.
    var summary: String = ""

    /// The full advisory text describing the vulnerability.
    var advisoryDescription: String = ""

    /// The package ecosystem (e.g., `"npm"`, `"pip"`, `"rubygems"`).
    var ecosystem: String = ""

    /// The range of package versions affected by this vulnerability.
    var vulnerableVersionRange: String = ""

    /// The GitHub Security Advisory identifier.
    var ghsaId: String = ""

    /// The CVE identifier, or `nil` if no CVE has been assigned.
    var cveId: String?

    /// The CVSS numeric severity score, or `nil` if not reported by the advisory.
    var cvssScore: Double?

    /// The URL of the alert on GitHub.com.
    var htmlUrl: String = ""

    /// The path to the dependency manifest file, or `nil` if not reported.
    var manifestPath: String?

    /// The GitHub login names of users assigned to remediate this alert.
    var assignedLogins: [String] = []

    /// The current state of this alert: `"open"`, `"dismissed"`, `"fixed"`, or `"auto_dismissed"`.
    var state: String = "open"

    /// The date the alert was resolved by a dependency update, or `nil` if not yet fixed.
    var fixedAt: Date?

    /// The date the alert was manually dismissed, or `nil` if not dismissed.
    var dismissedAt: Date?

    /// The reason given when this alert was dismissed (e.g. `"tolerable_risk"`), or `nil` if not dismissed.
    var dismissedReason: String?

    /// The date the alert was automatically dismissed by Dependabot, or `nil` if not auto-dismissed.
    var autoDismissedAt: Date?

    // MARK: - Computed

    /// The date the alert was resolved, regardless of how it was resolved.
    var resolvedAt: Date? { fixedAt ?? dismissedAt ?? autoDismissedAt }

    // MARK: - Init

    /// Creates a new Dependabot alert.
    ///
    /// - Parameters:
    ///   - alertNumber: The GitHub-assigned alert number, unique within the repository.
    ///   - packageName: The name of the vulnerable package.
    ///   - severity: The severity string as returned by the GitHub API.
    ///   - fixVersion: The version that resolves the vulnerability, or `nil` if unavailable.
    ///   - createdAt: The date the alert was opened on GitHub.
    ///   - summary: A brief description of the vulnerability; defaults to an empty string until synced.
    ///   - advisoryDescription: The full advisory text; defaults to an empty string until synced.
    ///   - ecosystem: The package ecosystem string; defaults to an empty string until synced.
    ///   - vulnerableVersionRange: The affected version range; defaults to an empty string until synced.
    ///   - ghsaId: The GitHub Security Advisory ID; defaults to an empty string until synced.
    ///   - cveId: The CVE identifier, or `nil` if none has been assigned.
    ///   - cvssScore: The CVSS score, or `nil` if not reported.
    ///   - htmlUrl: The URL of the alert on GitHub.com; defaults to an empty string until synced.
    ///   - manifestPath: The path to the manifest file, or `nil` if not reported.
    ///   - state: The current alert state; defaults to `"open"`.
    ///   - fixedAt: The date the alert was resolved by a dependency update, or `nil`.
    ///   - dismissedAt: The date the alert was manually dismissed, or `nil`.
    ///   - dismissedReason: The dismissal reason string, or `nil`.
    ///   - autoDismissedAt: The date the alert was automatically dismissed, or `nil`.
    init(
        alertNumber: Int,
        packageName: String,
        severity: String,
        fixVersion: String?,
        createdAt: Date,
        summary: String = "",
        advisoryDescription: String = "",
        ecosystem: String = "",
        vulnerableVersionRange: String = "",
        ghsaId: String = "",
        cveId: String? = nil,
        cvssScore: Double? = nil,
        htmlUrl: String = "",
        manifestPath: String? = nil,
        state: String = "open",
        fixedAt: Date? = nil,
        dismissedAt: Date? = nil,
        dismissedReason: String? = nil,
        autoDismissedAt: Date? = nil
    ) {
        self.alertNumber = alertNumber
        self.packageName = packageName
        self.severity = severity
        self.fixVersion = fixVersion
        self.createdAt = createdAt
        self.summary = summary
        self.advisoryDescription = advisoryDescription
        self.ecosystem = ecosystem
        self.vulnerableVersionRange = vulnerableVersionRange
        self.ghsaId = ghsaId
        self.cveId = cveId
        self.cvssScore = cvssScore
        self.htmlUrl = htmlUrl
        self.manifestPath = manifestPath
        self.state = state
        self.fixedAt = fixedAt
        self.dismissedAt = dismissedAt
        self.dismissedReason = dismissedReason
        self.autoDismissedAt = autoDismissedAt
    }

    // MARK: - Relationships

    /// The repository this alert belongs to.
    ///
    /// Set by SwiftData when the alert is appended to `SavedRepository.dependabotAlertDetails`.
    /// Inverse of ``SavedRepository/dependabotAlertDetails``.
    var repository: SavedRepository?
}
