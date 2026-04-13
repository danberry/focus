import Testing
@testable import Focus

/// Tests for `TeamService`.
@Suite("TeamService Tests")
struct TeamServiceTests {
    let mockHTTP = MockHTTPClient()

    /// Creates a `TeamService` wired to the shared `MockHTTPClient`.
    private func makeService() -> TeamService {
        let rest = RESTClient(httpClient: mockHTTP, tokenProvider: { "test-token" })
        return TeamService(rest: rest)
    }

    // MARK: - fetchTeams

    /// Verifies that a successful response is decoded into the expected list of teams.
    @Test func fetchTeamsReturnsList() async throws {
        mockHTTP.setSuccess(json: """
            [
                {
                    "id": 1,
                    "name": "Engineering",
                    "slug": "engineering",
                    "description": "The engineering team",
                    "privacy": "closed",
                    "members_count": 25,
                    "repos_count": 12
                },
                {
                    "id": 2,
                    "name": "Design",
                    "slug": "design",
                    "description": null,
                    "privacy": "secret",
                    "members_count": 8,
                    "repos_count": 3
                }
            ]
            """)

        let teams = try await makeService().fetchTeams(organization: "myorg")

        #expect(teams.count == 2)
        #expect(teams[0].name == "Engineering")
        #expect(teams[0].membersCount == 25)
        #expect(teams[1].slug == "design")
    }

    // MARK: - fetchTeamMembers

    /// Verifies that a successful response is decoded into the expected list of members.
    @Test func fetchTeamMembersReturnsList() async throws {
        mockHTTP.setSuccess(json: """
            [
                {"id": 1, "login": "alice", "avatar_url": "https://example.com/alice.png", "type": "User"},
                {"id": 2, "login": "bob", "avatar_url": null, "type": "User"}
            ]
            """)

        let members = try await makeService().fetchTeamMembers(
            organization: "myorg",
            teamSlug: "engineering"
        )

        #expect(members.count == 2)
        #expect(members[0].login == "alice")
        #expect(members[1].login == "bob")
    }
}
