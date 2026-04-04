import Foundation
import SwiftData

// MARK: - SavedRepository

@Model
final class SavedRepository {
    var githubId: String
    var name: String
    var primaryLanguage: String?

    init(githubId: String, name: String, primaryLanguage: String? = nil) {
        self.githubId = githubId
        self.name = name
        self.primaryLanguage = primaryLanguage
    }
}
