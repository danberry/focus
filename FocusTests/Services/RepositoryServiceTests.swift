import Testing
@testable import Focus

/// Tests for `RepositoryService`.
@Suite("RepositoryService Tests")
struct RepositoryServiceTests {
    let mockHTTP = MockHTTPClient()

    // MARK: - Setup

    /// Creates a `RepositoryService` wired to the shared `MockHTTPClient`.
    private func makeService() -> RepositoryService {
        let graphQL = GraphQLClient(httpClient: mockHTTP, tokenProvider: { "test-token" })
        return RepositoryService(graphQL: graphQL)
    }

    // MARK: - fetchRepository

    /// Verifies that a successful response is decoded into a `GitHubRepository` with correct field values.
    @Test func fetchRepositoryReturnsRepo() async throws {
        mockHTTP.setSuccess(json: """
            {
                "data": {
                    "repository": {
                        "id": "MDEwOlJlcG9zaXRvcnkx",
                        "name": "Hello-World",
                        "name_with_owner": "octocat/Hello-World",
                        "description": "My first repo",
                        "visibility": "PUBLIC",
                        "is_fork": false,
                        "stargazer_count": 1000,
                        "fork_count": 500,
                        "primary_language": {"name": "Swift"},
                        "url": "https://github.com/octocat/Hello-World",
                        "updated_at": "2024-01-01T00:00:00Z",
                        "owner": {"login": "octocat", "avatar_url": null}
                    }
                }
            }
            """)

        let repo = try await makeService().fetchRepository(owner: "octocat", name: "Hello-World")

        #expect(repo.name == "Hello-World")
        #expect(repo.stargazerCount == 1000)
        #expect(repo.primaryLanguage?.name == "Swift")
        #expect(repo.visibility == "PUBLIC")
    }

    // MARK: - fetchViewerRepositories

    /// Verifies that a paginated response is decoded with the correct nodes, cursor, and `hasNextPage` flag.
    @Test func fetchViewerRepositoriesReturnsPaginatedResults() async throws {
        mockHTTP.setSuccess(json: """
            {
                "data": {
                    "viewer": {
                        "repositories": {
                            "nodes": [
                                {
                                    "id": "1",
                                    "name": "repo-a",
                                    "name_with_owner": "me/repo-a",
                                    "description": null,
                                    "visibility": "PRIVATE",
                                    "is_fork": false,
                                    "stargazer_count": 0,
                                    "fork_count": 0,
                                    "primary_language": null,
                                    "url": "https://github.com/me/repo-a",
                                    "updated_at": null,
                                    "owner": {"login": "me", "avatar_url": null}
                                }
                            ],
                            "page_info": {
                                "end_cursor": "abc123",
                                "has_next_page": true
                            }
                        }
                    }
                }
            }
            """)

        let (repos, cursor, hasNext) = try await makeService().fetchViewerRepositories(first: 1)

        #expect(repos.count == 1)
        #expect(repos[0].name == "repo-a")
        #expect(cursor == "abc123")
        #expect(hasNext == true)
    }
}
