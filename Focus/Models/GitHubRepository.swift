import Foundation

struct GitHubRepository: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let name: String
    let nameWithOwner: String?
    let description: String?
    let isPrivate: Bool
    let isFork: Bool
    let stargazerCount: Int
    let forkCount: Int
    let primaryLanguage: Language?
    let url: String
    let updatedAt: String?
    let owner: Owner?

    struct Language: Codable, Sendable, Hashable {
        let name: String
    }

    struct Owner: Codable, Sendable, Hashable {
        let login: String
        let avatarUrl: String?
    }
}
