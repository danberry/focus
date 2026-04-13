import Foundation
import SwiftData

// MARK: - SecretScanningAlert

/// A GitHub secret scanning alert persisted for a watched repository.
///
/// `SecretScanningAlert` records the presence of an exposed secret detected by
/// GitHub's secret scanning feature. Each alert belongs to a single ``SavedRepository``.
@Model
final class SecretScanningAlert {

    // MARK: - Properties

    /// The GitHub-assigned alert number, unique within the repository.
    var alertNumber: Int

    /// The human-readable name of the secret type detected (e.g., "GitHub Personal Access Token").
    var secretTypeDisplayName: String

    /// The validity state of the detected secret as reported by GitHub (e.g., "active", "revoked").
    var validity: String

    /// Whether the secret has been detected in a public location outside the repository.
    var publiclyLeaked: Bool

    /// The date the alert was created on GitHub.
    var createdAt: Date

    // MARK: - Init

    /// Creates a new secret scanning alert.
    ///
    /// - Parameters:
    ///   - alertNumber: The GitHub-assigned alert number, unique within the repository.
    ///   - secretTypeDisplayName: The human-readable name of the detected secret type.
    ///   - validity: The validity state reported by GitHub.
    ///   - publiclyLeaked: Whether the secret has been publicly exposed outside the repository.
    ///   - createdAt: The date the alert was created on GitHub.
    init(
        alertNumber: Int,
        secretTypeDisplayName: String,
        validity: String,
        publiclyLeaked: Bool,
        createdAt: Date
    ) {
        self.alertNumber = alertNumber
        self.secretTypeDisplayName = secretTypeDisplayName
        self.validity = validity
        self.publiclyLeaked = publiclyLeaked
        self.createdAt = createdAt
    }

    // MARK: - Relationships

    /// The repository this alert belongs to.
    ///
    /// Set when the alert is inserted into the SwiftData graph. Cascade-deleted
    /// when the parent ``SavedRepository`` is removed. Inverse of ``SavedRepository/secretScanningAlertDetails``.
    var repository: SavedRepository?
}
