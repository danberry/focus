import Foundation

struct GitHubUser: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let login: String
    let name: String?
    let avatarUrl: String?
    let bio: String?
    let company: String?
    let location: String?
    let email: String?
    let publicRepos: Int?
    let followers: Int?
    let following: Int?
}
