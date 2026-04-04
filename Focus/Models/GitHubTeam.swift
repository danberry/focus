import Foundation

struct GitHubTeam: Codable, Sendable, Hashable, Identifiable {
    let id: Int
    let name: String
    let slug: String
    let description: String?
    let privacy: String?
    let membersCount: Int?
    let reposCount: Int?
}
