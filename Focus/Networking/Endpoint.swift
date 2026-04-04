import Foundation

// MARK: - Endpoint

enum Endpoint {
    case teams(org: String)
    case teamMembers(org: String, teamSlug: String)
    case teamRepos(org: String, teamSlug: String)

    var path: String {
        switch self {
        case .teams(let org):
            "/orgs/\(org)/teams"
        case .teamMembers(let org, let teamSlug):
            "/orgs/\(org)/teams/\(teamSlug)/members"
        case .teamRepos(let org, let teamSlug):
            "/orgs/\(org)/teams/\(teamSlug)/repos"
        }
    }
}
