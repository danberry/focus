import Testing
@testable import Focus

@Suite("UserService Tests")
struct UserServiceTests {
    let mockHTTP = MockHTTPClient()

    private func makeService() -> UserService {
        let graphQL = GraphQLClient(httpClient: mockHTTP, tokenProvider: { "test-token" })
        return UserService(graphQL: graphQL)
    }

    @Test func fetchViewerReturnsUser() async throws {
        mockHTTP.setSuccess(json: """
            {
                "data": {
                    "viewer": {
                        "id": "MDQ6VXNlcjE=",
                        "login": "octocat",
                        "name": "The Octocat",
                        "avatar_url": "https://github.com/images/octocat.png",
                        "bio": "A cat",
                        "company": "GitHub",
                        "location": "San Francisco",
                        "email": "octocat@github.com",
                        "public_repos": {"total_count": 10},
                        "followers": {"total_count": 100},
                        "following": {"total_count": 5}
                    }
                }
            }
            """)

        let user = try await makeService().fetchViewer()

        #expect(user.login == "octocat")
        #expect(user.name == "The Octocat")
        #expect(user.publicRepos == 10)
        #expect(user.followers == 100)
    }

    @Test func fetchUserByLoginReturnsUser() async throws {
        mockHTTP.setSuccess(json: """
            {
                "data": {
                    "user": {
                        "id": "MDQ6VXNlcjI=",
                        "login": "torvalds",
                        "name": "Linus Torvalds",
                        "avatar_url": null,
                        "bio": null,
                        "company": null,
                        "location": "Portland, OR",
                        "email": null,
                        "public_repos": {"total_count": 7},
                        "followers": {"total_count": 200000},
                        "following": {"total_count": 0}
                    }
                }
            }
            """)

        let user = try await makeService().fetchUser(login: "torvalds")

        #expect(user.login == "torvalds")
        #expect(user.location == "Portland, OR")
    }
}
