import Foundation
import SwiftData

// MARK: - SavedOrganization

@Model
final class SavedOrganization {
    var githubId: String
    var login: String
    var name: String?
    var avatarUrl: String?
    var organizationDescription: String?
    var addedAt: Date

    init(githubId: String, login: String, name: String? = nil, avatarUrl: String? = nil, organizationDescription: String? = nil) {
        self.githubId = githubId
        self.login = login
        self.name = name
        self.avatarUrl = avatarUrl
        self.organizationDescription = organizationDescription
        self.addedAt = Date()
    }
}
