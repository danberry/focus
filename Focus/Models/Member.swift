import Foundation
import SwiftData

// MARK: - Member

@Model
final class Member {
    var name: String
    var githubId: Int?
    var team: Team?

    init(name: String, githubId: Int? = nil) {
        self.name = name
        self.githubId = githubId
    }
}
