import Foundation
import SwiftData

// MARK: - DependabotAlert

@Model
final class DependabotAlert {
    var alertNumber: Int
    var packageName: String
    var severity: String
    var fixVersion: String?
    var createdAt: Date
    var repository: SavedRepository?

    init(
        alertNumber: Int,
        packageName: String,
        severity: String,
        fixVersion: String?,
        createdAt: Date
    ) {
        self.alertNumber = alertNumber
        self.packageName = packageName
        self.severity = severity
        self.fixVersion = fixVersion
        self.createdAt = createdAt
    }
}
