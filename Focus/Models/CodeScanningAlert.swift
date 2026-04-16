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

    /// The stable identifier for the rule (e.g., `"js/sql-injection"`), or `nil` if not provided.
    var ruleId: String?

    /// A short description of what the rule checks for, or `nil` if not provided.
    var ruleDescription: String?

    /// The name of the analysis tool that produced this alert (e.g., `"CodeQL"`), or `nil` if not provided.
    var toolName: String?

    /// The file path of the most recent alert instance, or `nil` if not reported.
    var locationPath: String?

    /// The starting line number of the most recent alert instance, or `nil` if not reported.
    var locationStartLine: Int?

    /// The human-readable message text describing the specific finding, or `nil` if not reported.
    var messageText: String?

    // MARK: - Init

    /// Creates a new code scanning alert.
    ///
    /// - Parameters:
    ///   - alertNumber: The unique number identifying this alert within the repository.
    ///   - ruleName: The name of the code scanning rule that triggered this alert.
    ///   - securitySeverityLevel: The security severity level, or `nil` if none is reported.
    ///   - createdAt: The date and time when this alert was created on GitHub.
    ///   - htmlUrl: The GitHub web URL for viewing this alert's detail page.
    ///   - ruleId: The stable rule identifier, or `nil` if not provided.
    ///   - ruleDescription: A short description of what the rule checks for, or `nil` if not provided.
    ///   - toolName: The analysis tool name, or `nil` if not provided.
    ///   - locationPath: The file path of the most recent instance, or `nil` if not reported.
    ///   - locationStartLine: The starting line number of the most recent instance, or `nil` if not reported.
    ///   - messageText: The human-readable finding message, or `nil` if not reported.
    init(
        alertNumber: Int,
        ruleName: String,
        securitySeverityLevel: String?,
        createdAt: Date,
        htmlUrl: String,
        ruleId: String? = nil,
        ruleDescription: String? = nil,
        toolName: String? = nil,
        locationPath: String? = nil,
        locationStartLine: Int? = nil,
        messageText: String? = nil
    ) {
        self.alertNumber = alertNumber
        self.ruleName = ruleName
        self.securitySeverityLevel = securitySeverityLevel
        self.createdAt = createdAt
        self.htmlUrl = htmlUrl
        self.ruleId = ruleId
        self.ruleDescription = ruleDescription
        self.toolName = toolName
        self.locationPath = locationPath
        self.locationStartLine = locationStartLine
        self.messageText = messageText
    }

    // MARK: - Relationships

    /// The repository this alert belongs to.
    ///
    /// `nil` until the alert is associated with a ``SavedRepository``.
    /// Inverse of ``SavedRepository/codeScanningAlertDetails``.
    var repository: SavedRepository?
}
