import Foundation
import SwiftData

// MARK: - Team

@Model
final class Team {
    var name: String
    var teamDescription: String

    init(name: String, teamDescription: String) {
        self.name = name
        self.teamDescription = teamDescription
    }
}
