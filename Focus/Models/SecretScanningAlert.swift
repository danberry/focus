import Foundation
import SwiftData

// MARK: - SecretScanningAlert

@Model
final class SecretScanningAlert {
    var repository: SavedRepository?
    var alertNumber: Int
    var secretTypeDisplayName: String
    var validity: String
    var publiclyLeaked: Bool
    var createdAt: Date

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
}
