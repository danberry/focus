import Foundation

struct GitHubOrganization: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let login: String
    let name: String?
    let avatarUrl: String?
    let description: String?

    enum CodingKeys: String, CodingKey {
        case id = "nodeId"
        case login
        case name
        case avatarUrl
        case description
    }
}
