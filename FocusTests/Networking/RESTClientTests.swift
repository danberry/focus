import Testing
import Foundation
@testable import Focus

@Suite("RESTClient Tests")
struct RESTClientTests {
    let mockHTTP = MockHTTPClient()

    private func makeClient() -> RESTClient {
        RESTClient(httpClient: mockHTTP, tokenProvider: { "test-token" })
    }

    @Test func sendsCorrectHeaders() async throws {
        mockHTTP.setSuccess(json: "[]")

        let _: [GitHubTeam] = try await makeClient().get(path: "/orgs/test/teams")

        let request = try #require(mockHTTP.lastRequest)
        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/vnd.github+json")
        #expect(request.value(forHTTPHeaderField: "X-GitHub-Api-Version") == "2022-11-28")
    }

    @Test func decodesArrayResponse() async throws {
        mockHTTP.setSuccess(json: """
            [{"id": 1, "name": "Engineering", "slug": "engineering", "description": "Eng team", "privacy": "closed", "members_count": 10, "repos_count": 5}]
            """)

        let teams: [GitHubTeam] = try await makeClient().get(path: "/orgs/test/teams")

        #expect(teams.count == 1)
        #expect(teams[0].name == "Engineering")
        #expect(teams[0].slug == "engineering")
    }

    @Test func throwsNotFoundOn404() async throws {
        mockHTTP.setSuccess(json: "{\"message\": \"Not Found\"}", statusCode: 404)

        await #expect(throws: GitHubError.self) {
            let _: [GitHubTeam] = try await makeClient().get(path: "/orgs/nonexistent/teams")
        }
    }
}
