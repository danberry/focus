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
    var summary: String
    var advisoryDescription: String
    var ecosystem: String
    var vulnerableVersionRange: String
    var ghsaId: String
    var cveId: String?
    var cvssScore: Double?
    var htmlUrl: String
    var manifestPath: String?

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
        manifestPath: String? = nil
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
    }
}
