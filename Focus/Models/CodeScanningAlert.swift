import Foundation
import SwiftData

// MARK: - CodeScanningAlert

@Model
final class CodeScanningAlert {
    var alertNumber: Int
    var ruleName: String
    var securitySeverityLevel: String?
    var createdAt: Date
    var htmlUrl: String
    var repository: SavedRepository?

    init(alertNumber: Int, ruleName: String, securitySeverityLevel: String?, createdAt: Date, htmlUrl: String) {
        self.alertNumber = alertNumber
        self.ruleName = ruleName
        self.securitySeverityLevel = securitySeverityLevel
        self.createdAt = createdAt
        self.htmlUrl = htmlUrl
    }
}
