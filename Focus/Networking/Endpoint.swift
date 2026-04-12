import Foundation

// MARK: - Endpoint

/// Describes a GitHub REST API endpoint as a strongly typed enum.
///
/// Each case maps to a specific REST resource. Use the ``path`` property to
/// obtain the URL path component for constructing a `URLRequest`.
///
/// - Note: All paths are relative to the GitHub REST API base URL
///   (`https://api.github.com`). No query parameters are included;
///   callers are responsible for appending them as needed.
// TODO: Add an `httpMethod` property — several endpoints (e.g., PATCH for alert dismissal) require non-GET methods, and encoding that here would prevent callers from hardcoding method strings.
enum Endpoint {

    // MARK: - Cases

    /// Returns the teams for the given organization.
    case teams(org: String)

    /// Returns the members of a specific team within an organization.
    case teamMembers(org: String, teamSlug: String)

    /// Returns the repositories accessible to a specific team within an organization.
    case teamRepos(org: String, teamSlug: String)

    /// Returns the open Dependabot alerts for a repository.
    case dependabotAlerts(owner: String, repo: String)

    /// Returns the code scanning alerts for a repository.
    case codeScanningAlerts(owner: String, repo: String)

    /// Returns the secret scanning alerts for a repository.
    case secretScanningAlerts(owner: String, repo: String)

    /// Returns the contents at a specific path within a repository.
    ///
    /// - Note: `path` is interpolated directly into the URL. File names containing
    ///   spaces or special characters will produce a malformed request.
    // TODO: Percent-encode the `path` parameter before interpolation — unencoded spaces or special characters in file paths will cause the request to fail or hit the wrong resource.
    case repoContents(owner: String, repo: String, path: String)

    /// Returns a single Dependabot alert identified by its alert number.
    case dependabotAlert(owner: String, repo: String, alertNumber: Int)

    /// Returns the public profile for a GitHub user.
    case userProfile(login: String)

    /// Returns the public profile for a GitHub organization.
    case organization(login: String)

    // MARK: - Computed Properties

    /// The URL path component for this endpoint, relative to the GitHub REST API base URL.
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
        case .repoContents(let owner, let repo, let path):
            "/repos/\(owner)/\(repo)/contents/\(path)"
        case .dependabotAlert(let owner, let repo, let alertNumber):
            "/repos/\(owner)/\(repo)/dependabot/alerts/\(alertNumber)"
        case .userProfile(let login):
            "/users/\(login)"
        case .organization(let login):
            "/orgs/\(login)"
        }
    }
}
