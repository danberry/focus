import Foundation

struct GitHubOrganization: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let login: String
    let name: String?
    let avatarUrl: String?
    let description: String?
}
