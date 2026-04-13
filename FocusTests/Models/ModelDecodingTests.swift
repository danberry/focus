import Testing
import Foundation
@testable import Focus

/// Tests for model JSON decoding.
@Suite("Model Decoding Tests")
struct ModelDecodingTests {

    /// A JSON decoder configured with snake_case key conversion for GitHub API responses.
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    // MARK: - GitHubUser

    /// Verifies that a fully populated user payload decodes all fields correctly.
    @Test func decodesGitHubUser() throws {
        let json = """
            {
                "id": "MDQ6VXNlcjE=",
                "login": "octocat",
                "name": "The Octocat",
                "avatar_url": "https://github.com/images/octocat.png",
                "bio": "A GitHub mascot",
                "company": "GitHub",
                "location": "San Francisco",
                "email": "octocat@github.com",
                "public_repos": 10,
                "followers": 100,
                "following": 5
            }
            """
        let user = try decoder.decode(GitHubUser.self, from: json.data(using: .utf8)!)

        #expect(user.login == "octocat")
        #expect(user.name == "The Octocat")
        #expect(user.company == "GitHub")
    }

    /// Verifies that optional fields decode as `nil` when the API returns null.
    @Test func decodesGitHubUserWithNulls() throws {
        let json = """
            {
                "id": "1",
                "login": "minimal",
                "name": null,
                "avatar_url": null,
                "bio": null,
                "company": null,
                "location": null,
                "email": null,
                "public_repos": null,
                "followers": null,
                "following": null
            }
            """
        let user = try decoder.decode(GitHubUser.self, from: json.data(using: .utf8)!)

        #expect(user.login == "minimal")
        #expect(user.name == nil)
        #expect(user.publicRepos == nil)
    }

    // MARK: - GitHubRepository

    /// Verifies that a repository payload with nested language and owner objects decodes correctly.
    @Test func decodesGitHubRepository() throws {
        let json = """
            {
                "id": "MDEwOlJlcG9zaXRvcnkx",
                "name": "Hello-World",
                "name_with_owner": "octocat/Hello-World",
                "description": "My first repo",
                "is_private": false,
                "is_fork": false,
                "stargazer_count": 1000,
                "fork_count": 500,
                "primary_language": {"name": "Swift"},
                "url": "https://github.com/octocat/Hello-World",
                "updated_at": "2024-01-01T00:00:00Z",
                "owner": {"login": "octocat", "avatar_url": "https://example.com/avatar.png"}
            }
            """
        let repo = try decoder.decode(GitHubRepository.self, from: json.data(using: .utf8)!)

        #expect(repo.name == "Hello-World")
        #expect(repo.stargazerCount == 1000)
        #expect(repo.primaryLanguage?.name == "Swift")
        #expect(repo.owner?.login == "octocat")
    }

    // MARK: - GitHubTeam

    /// Verifies that a team payload with member and repo counts decodes correctly.
    @Test func decodesGitHubTeam() throws {
        let json = """
            {
                "id": 42,
                "name": "Engineering",
                "slug": "engineering",
                "description": "The eng team",
                "privacy": "closed",
                "members_count": 25,
                "repos_count": 12
            }
            """
        let team = try decoder.decode(GitHubTeam.self, from: json.data(using: .utf8)!)

        #expect(team.id == 42)
        #expect(team.name == "Engineering")
        #expect(team.slug == "engineering")
        #expect(team.membersCount == 25)
    }

    // MARK: - GitHubOrganization

    /// Verifies that an organization payload decodes the node ID into the `id` field.
    @Test func decodesGitHubOrganization() throws {
        let json = """
            {
                "id": 9919,
                "node_id": "MDEyOk9yZ2FuaXphdGlvbjE=",
                "login": "github",
                "name": "GitHub",
                "avatar_url": "https://github.com/images/github.png",
                "description": "How people build software"
            }
            """
        let org = try decoder.decode(GitHubOrganization.self, from: json.data(using: .utf8)!)

        #expect(org.id == "MDEyOk9yZ2FuaXphdGlvbjE=")
        #expect(org.login == "github")
        #expect(org.name == "GitHub")
    }
}
