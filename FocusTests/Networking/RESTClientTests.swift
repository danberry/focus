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
}
