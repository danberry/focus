import Foundation
import SwiftData

// MARK: - SavedOrganization

@Model
final class SavedOrganization {
    var login: String
    var name: String?
    var avatarUrl: String?
    var organizationDescription: String?
    var addedAt: Date

    init(login: String, name: String? = nil, avatarUrl: String? = nil, organizationDescription: String? = nil) {
        self.login = login
        self.name = name
        self.avatarUrl = avatarUrl
        self.organizationDescription = organizationDescription
        self.addedAt = Date()
    }
}
