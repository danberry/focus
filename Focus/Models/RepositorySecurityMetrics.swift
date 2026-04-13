import Foundation

// MARK: - RepositorySecurityMetrics

/// A lightweight count-only snapshot of open security alerts for a GitHub repository.
///
/// All three counts are optional; `nil` indicates that the alert type is unavailable
/// for the repository — typically because the feature is disabled or the token lacks
/// the required scope.
struct RepositorySecurityMetrics: Sendable {

    // MARK: - Properties

    /// The number of open Dependabot alerts, or `nil` if the feature is unavailable.
    let dependabotAlerts: Int?

    /// The number of open code scanning alerts, or `nil` if the feature is unavailable.
    let codeScanningAlerts: Int?

    /// The number of open secret scanning alerts, or `nil` if the feature is unavailable.
    let secretScanningAlerts: Int?
}
