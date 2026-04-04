import Foundation

// MARK: - Endpoint

enum Endpoint {
    case teams(org: String)
    case teamMembers(org: String, teamSlug: String)
    case teamRepos(org: String, teamSlug: String)
    case dependabotAlerts(owner: String, repo: String)
    case codeScanningAlerts(owner: String, repo: String)
    case secretScanningAlerts(owner: String, repo: String)

    var path: String {
        switch self {
        case .teams(let org):
            "/orgs/\(org)/teams"
        case .teamMembers(let org, let teamSlug):
            "/orgs/\(org)/teams/\(teamSlug)/members"
        case .teamRepos(let org, let teamSlug):
            "/orgs/\(org)/teams/\(teamSlug)/repos"
        case .dependabotAlerts(let owner, let repo):
            "/repos/\(owner)/\(repo)/dependabot/alerts"
        case .codeScanningAlerts(let owner, let repo):
            "/repos/\(owner)/\(repo)/code-scanning/alerts"
        case .secretScanningAlerts(let owner, let repo):
            "/repos/\(owner)/\(repo)/secret-scanning/alerts"
        }
    }
}
