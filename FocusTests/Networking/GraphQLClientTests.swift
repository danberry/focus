import Testing
@testable import Focus

/// Tests for `GraphQLClient`.
@Suite("GraphQLClient Tests")
struct GraphQLClientTests {
    let mockHTTP = MockHTTPClient()

    // MARK: - Setup

    /// Creates a `GraphQLClient` wired to the shared `MockHTTPClient`.
    private func makeClient() -> GraphQLClient {
        GraphQLClient(httpClient: mockHTTP, tokenProvider: { "test-token" })
    }

    // MARK: - execute

    /// Verifies that the client sends a POST request with the correct Authorization and Content-Type headers.
    @Test func sendsCorrectRequestFormat() async throws {
        mockHTTP.setSuccess(json: """
            {"data": {"viewer": {"login": "octocat"}}}
            """)

        struct Response: Decodable, Sendable {
            let viewer: Viewer
            struct Viewer: Decodable, Sendable { let login: String }
        }

        _ = try await makeClient().execute(
            query: "query { viewer { login } }",
            responseType: Response.self
        )

        let request = try #require(mockHTTP.lastRequest)
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
    }

    /// Verifies that the client decodes a `data` envelope into the expected response type.
    @Test func decodesSuccessfulResponse() async throws {
        mockHTTP.setSuccess(json: """
            {"data": {"viewer": {"login": "octocat", "name": "The Octocat"}}}
            """)

        struct Response: Decodable, Sendable {
            let viewer: Viewer
            struct Viewer: Decodable, Sendable {
                let login: String
                let name: String
            }
        }

        let result = try await makeClient().execute(
            query: "query { viewer { login name } }",
            responseType: Response.self
        )

        #expect(result.viewer.login == "octocat")
        #expect(result.viewer.name == "The Octocat")
    }

    /// Verifies that a response containing GraphQL errors throws a `GitHubError`.
    @Test func throwsOnGraphQLErrors() async throws {
        mockHTTP.setSuccess(json: """
            {"data": null, "errors": [{"message": "Not found", "path": ["user"]}]}
            """)

        struct Response: Decodable, Sendable {
            let user: String
        }

        await #expect(throws: GitHubError.self) {
            _ = try await makeClient().execute(
                query: "query { user }",
                responseType: Response.self
            )
        }
    }

    /// Verifies that a 401 HTTP response throws a `GitHubError`.
    @Test func throwsUnauthorizedOn401() async throws {
        mockHTTP.setSuccess(json: "{}", statusCode: 401)

        struct Response: Decodable, Sendable {}

        await #expect(throws: GitHubError.self) {
            _ = try await makeClient().execute(
                query: "query { viewer { login } }",
                responseType: Response.self
            )
        }
    }
}
