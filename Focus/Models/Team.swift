import Foundation
import SwiftData

// MARK: - Team

@Model
final class Team {
    var name: String
    var teamDescription: String
    @Relationship(deleteRule: .cascade, inverse: \Member.team)
    var members: [Member] = []

    init(name: String, teamDescription: String) {
        self.name = name
        self.teamDescription = teamDescription
    }
}
