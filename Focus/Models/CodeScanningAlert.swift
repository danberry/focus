import Foundation
import SwiftData

// MARK: - CodeScanningAlert

/// A GitHub code scanning alert persisted for a watched repository.
///
/// `CodeScanningAlert` records the alert number, rule, severity, and creation
/// date reported by the GitHub code scanning API. Cascade-deleted when its
/// parent ``SavedRepository`` is removed.
@Model
final class CodeScanningAlert {

    // MARK: - Properties

    /// The unique number identifying this alert within the repository.
    var alertNumber: Int

    /// The name of the code scanning rule that triggered this alert.
    var ruleName: String

    /// The security severity level reported for this alert, or `nil` if the rule has no associated severity.
    var securitySeverityLevel: String?

    /// The date and time when this alert was created on GitHub.
    var createdAt: Date

    /// The GitHub web URL for viewing this alert's detail page.
    var htmlUrl: String

    // MARK: - Init

    /// Creates a new code scanning alert.
    ///
    /// - Parameters:
    ///   - alertNumber: The unique number identifying this alert within the repository.
    ///   - ruleName: The name of the code scanning rule that triggered this alert.
    ///   - securitySeverityLevel: The security severity level, or `nil` if none is reported.
    ///   - createdAt: The date and time when this alert was created on GitHub.
    ///   - htmlUrl: The GitHub web URL for viewing this alert's detail page.
    init(alertNumber: Int, ruleName: String, securitySeverityLevel: String?, createdAt: Date, htmlUrl: String) {
        self.alertNumber = alertNumber
        self.ruleName = ruleName
        self.securitySeverityLevel = securitySeverityLevel
        self.createdAt = createdAt
        self.htmlUrl = htmlUrl
    }

    // MARK: - Relationships

    /// The repository this alert belongs to.
    ///
    /// `nil` until the alert is associated with a ``SavedRepository``.
    /// Inverse of ``SavedRepository/codeScanningAlertDetails``.
    var repository: SavedRepository?
}
