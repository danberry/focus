import Foundation
import SwiftData

// MARK: - SavedRepository

@Model
final class SavedRepository {
    var githubId: String
    var owner: String
    var name: String
    var displayName: String
    var primaryLanguage: String?
    var dependabotAlerts: Int
    var codeScanningAlerts: Int
    var secretScanningAlerts: Int

    init(
        githubId: String,
        owner: String,
        name: String,
        displayName: String,
        primaryLanguage: String? = nil,
        dependabotAlerts: Int = 0,
        codeScanningAlerts: Int = 0,
        secretScanningAlerts: Int = 0
    ) {
        self.githubId = githubId
        self.owner = owner
        self.name = name
        self.displayName = displayName
        self.primaryLanguage = primaryLanguage
        self.dependabotAlerts = dependabotAlerts
        self.codeScanningAlerts = codeScanningAlerts
        self.secretScanningAlerts = secretScanningAlerts
    }

    // MARK: - Relationships

    @Relationship(deleteRule: .cascade, inverse: \DependabotAlert.repository)
    var dependabotAlertDetails: [DependabotAlert] = []

    @Relationship(deleteRule: .cascade, inverse: \CodeScanningAlert.repository)
    var codeScanningAlertDetails: [CodeScanningAlert] = []

    @Relationship(deleteRule: .cascade, inverse: \SecretScanningAlert.repository)
    var secretScanningAlertDetails: [SecretScanningAlert] = []

    @Relationship(deleteRule: .cascade, inverse: \Codeowner.repository)
    var codeowners: [Codeowner] = []

    @Relationship(deleteRule: .cascade, inverse: \RepositoryVelocity.repository)
    var velocityMetrics: [RepositoryVelocity] = []

    // MARK: - Computed

    var totalSecurityAlerts: Int {
        dependabotAlerts + codeScanningAlerts + secretScanningAlerts
    }
}
