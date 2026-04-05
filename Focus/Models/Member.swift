import Foundation
import SwiftData

// MARK: - Member

@Model
final class Member {
    var name: String
    var githubId: Int?
    var githubLogin: String?
    var contributionCount: Int = 0
    var team: Team?

    @Relationship(deleteRule: .cascade, inverse: \MemberContribution.member)
    var contributions: [MemberContribution] = []

    init(name: String, githubId: Int? = nil, githubLogin: String? = nil) {
        self.name = name
        self.githubId = githubId
        self.githubLogin = githubLogin
    }

    // MARK: - Computed

    var totalContributions: Int { contributionCount }
}
