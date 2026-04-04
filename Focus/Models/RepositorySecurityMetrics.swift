import Foundation

// MARK: - RepositorySecurityMetrics

struct RepositorySecurityMetrics: Sendable {
    let dependabotAlerts: Int?
    let codeScanningAlerts: Int?
    let secretScanningAlerts: Int?
}
