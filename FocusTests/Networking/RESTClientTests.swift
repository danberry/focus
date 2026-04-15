import Testing
import Foundation
@testable import Focus

/// Tests for ``RESTClient``.
@Suite("RESTClient Tests")
struct RESTClientTests {
    let mockHTTP = MockHTTPClient()

    /// Creates a ``RESTClient`` wired to the shared ``MockHTTPClient``.
    private func makeClient() -> RESTClient {
        RESTClient(httpClient: mockHTTP, tokenProvider: { "test-token" })
    }

    /// Verifies that `get` attaches the Authorization, Accept, and GitHub API version headers to every request.
    @Test func sendsCorrectHeaders() async throws {
        mockHTTP.setSuccess(json: "[]")

        let _: [GitHubTeam] = try await makeClient().get(path: "/orgs/test/teams")

        let request = try #require(mockHTTP.lastRequest)
        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/vnd.github+json")
        #expect(request.value(forHTTPHeaderField: "X-GitHub-Api-Version") == "2022-11-28")
    }

    /// Verifies that `get` decodes a JSON array response into the expected model array.
    @Test func decodesArrayResponse() async throws {
        mockHTTP.setSuccess(json: """
            [{"id": 1, "name": "Engineering", "slug": "engineering", "description": "Eng team", "privacy": "closed", "members_count": 10, "repos_count": 5}]
            """)

        let teams: [GitHubTeam] = try await makeClient().get(path: "/orgs/test/teams")

        #expect(teams.count == 1)
        #expect(teams[0].name == "Engineering")
        #expect(teams[0].slug == "engineering")
    }

    /// Verifies that `get` throws a ``GitHubError`` when the server responds with a 404 status code.
    @Test func throwsNotFoundOn404() async throws {
        mockHTTP.setSuccess(json: "{\"message\": \"Not Found\"}", statusCode: 404)

        await #expect(throws: GitHubError.self) {
            let _: [GitHubTeam] = try await makeClient().get(path: "/orgs/nonexistent/teams")
        }
    }

    // MARK: - getAll

    /// Verifies that `getAll` returns all items when the response has no `Link` header (single page).
    @Test func getAllReturnsSinglePageWhenNoLinkHeader() async throws {
        mockHTTP.setSuccess(json: """
            [
              {"id": 1, "name": "Team A", "slug": "team-a", "description": "", "privacy": "closed", "members_count": 1, "repos_count": 0},
              {"id": 2, "name": "Team B", "slug": "team-b", "description": "", "privacy": "closed", "members_count": 2, "repos_count": 0}
            ]
            """)

        let teams: [GitHubTeam] = try await makeClient().getAll(path: "/orgs/test/teams")

        #expect(teams.count == 2)
        #expect(teams[0].name == "Team A")
        #expect(teams[1].name == "Team B")
    }

    /// Verifies that `getAll` follows the `Link: rel="next"` header and accumulates all pages.
    @Test func getAllFollowsLinkHeaderAcrossPages() async throws {
        // Page 1: one team, Link header pointing to page 2
        mockHTTP.enqueueSuccess(
            json: """
            [{"id": 1, "name": "Team A", "slug": "team-a", "description": "", "privacy": "closed", "members_count": 1, "repos_count": 0}]
            """,
            headers: ["Link": "<https://api.github.com/orgs/test/teams?page=2>; rel=\"next\""]
        )
        // Page 2: one team, no Link header
        mockHTTP.enqueueSuccess(
            json: """
            [{"id": 2, "name": "Team B", "slug": "team-b", "description": "", "privacy": "closed", "members_count": 2, "repos_count": 0}]
            """
        )

        let teams: [GitHubTeam] = try await makeClient().getAll(path: "/orgs/test/teams")

        #expect(teams.count == 2)
        #expect(teams[0].name == "Team A")
        #expect(teams[1].name == "Team B")
    }

    /// Verifies that `getAll` accumulates all items across three pages.
    @Test func getAllAccumulatesThreePages() async throws {
        let linkToPage2 = ["Link": "<https://api.github.com/orgs/test/teams?page=2>; rel=\"next\", <https://api.github.com/orgs/test/teams?page=3>; rel=\"last\""]
        let linkToPage3 = ["Link": "<https://api.github.com/orgs/test/teams?page=3>; rel=\"next\""]
        let teamA = "[{\"id\": 1, \"name\": \"Team A\", \"slug\": \"team-a\", \"description\": \"\", \"privacy\": \"closed\", \"members_count\": 0, \"repos_count\": 0}]"
        let teamB = "[{\"id\": 2, \"name\": \"Team B\", \"slug\": \"team-b\", \"description\": \"\", \"privacy\": \"closed\", \"members_count\": 0, \"repos_count\": 0}]"
        let teamC = "[{\"id\": 3, \"name\": \"Team C\", \"slug\": \"team-c\", \"description\": \"\", \"privacy\": \"closed\", \"members_count\": 0, \"repos_count\": 0}]"

        mockHTTP.enqueueSuccess(json: teamA, headers: linkToPage2)
        mockHTTP.enqueueSuccess(json: teamB, headers: linkToPage3)
        mockHTTP.enqueueSuccess(json: teamC)

        let teams: [GitHubTeam] = try await makeClient().getAll(path: "/orgs/test/teams")

        #expect(teams.count == 3)
        #expect(teams.map(\.name) == ["Team A", "Team B", "Team C"])
    }

    /// Verifies that `getAll` throws on a non-2xx response and does not return partial results.
    @Test func getAllThrowsOnHTTPError() async throws {
        mockHTTP.setSuccess(json: "{}", statusCode: 403)

        await #expect(throws: GitHubError.self) {
            let _: [GitHubTeam] = try await makeClient().getAll(path: "/orgs/test/teams")
        }
    }

    /// Verifies that `getAll` sends the correct headers on paginated follow-up requests.
    @Test func getAllSendsAuthHeaderOnFollowUpPages() async throws {
        let teamA = "[{\"id\": 1, \"name\": \"Team A\", \"slug\": \"team-a\", \"description\": \"\", \"privacy\": \"closed\", \"members_count\": 0, \"repos_count\": 0}]"
        let teamB = "[{\"id\": 2, \"name\": \"Team B\", \"slug\": \"team-b\", \"description\": \"\", \"privacy\": \"closed\", \"members_count\": 0, \"repos_count\": 0}]"
        mockHTTP.enqueueSuccess(
            json: teamA,
            headers: ["Link": "<https://api.github.com/orgs/test/teams?page=2>; rel=\"next\""]
        )
        mockHTTP.enqueueSuccess(json: teamB)

        let _: [GitHubTeam] = try await makeClient().getAll(path: "/orgs/test/teams")

        // lastRequest is the final request (page 2) — verify it still carries auth
        let request = try #require(mockHTTP.lastRequest)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/vnd.github+json")
    }
}
