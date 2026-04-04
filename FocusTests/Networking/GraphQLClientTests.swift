import Testing
@testable import Focus

@Suite("GraphQLClient Tests")
struct GraphQLClientTests {
    let mockHTTP = MockHTTPClient()

    private func makeClient() -> GraphQLClient {
        GraphQLClient(httpClient: mockHTTP, tokenProvider: { "test-token" })
    }

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
