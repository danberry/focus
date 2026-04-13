import Foundation
import Testing
@testable import Focus

/// Tests for `MergedPRReportService`.
@Suite("MergedPRReportService Tests")
struct MergedPRReportServiceTests {
    let mockHTTP = MockHTTPClient()

    // MARK: - Setup

    /// Creates a `MergedPRReportService` wired to the shared `MockHTTPClient`.
    private func makeService() -> MergedPRReportService {
        let graphQL = GraphQLClient(httpClient: mockHTTP, tokenProvider: { "test-token" })
        return MergedPRReportService(graphQL: graphQL)
    }

    /// Creates a JSON response string with the given PR nodes and pagination metadata.
    private func makeResponse(nodes: [String], hasNextPage: Bool = false, endCursor: String? = nil) -> String {
        let cursor = endCursor.map { "\"\($0)\"" } ?? "null"
        return """
        {
          "data": {
            "search": {
              "pageInfo": {
                "endCursor": \(cursor),
                "hasNextPage": \(hasNextPage)
              },
              "nodes": [\(nodes.joined(separator: ",\n"))]
            }
          }
        }
        """
    }

    /// Creates a JSON fragment representing a single merged PR node.
    private func prNode(number: Int, title: String, mergedAt: String, login: String, url: String, repo: String) -> String {
        """
        {
          "number": \(number),
          "title": "\(title)",
          "mergedAt": "\(mergedAt)",
          "author": { "login": "\(login)" },
          "url": "\(url)",
          "repository": { "nameWithOwner": "\(repo)" }
        }
        """
    }

    // MARK: - fetchMergedPRs

    /// Verifies that passing an empty repository list returns an empty result without making a network request.
    @Test func emptyRepositoriesReturnsEmptyDictWithoutCallingAPI() async throws {
        // No mock response set — if the API were called, MockHTTPClient would fatalError.
        let result = try await makeService().fetchMergedPRs(for: [], on: Date())
        #expect(result.isEmpty)
        #expect(mockHTTP.lastRequest == nil)
    }

    /// Verifies that all fields of a single merged PR are decoded and mapped correctly.
    @Test func parsesSinglePRFieldsCorrectly() async throws {
        mockHTTP.setSuccess(json: makeResponse(nodes: [
            prNode(
                number: 42,
                title: "Fix memory leak",
                mergedAt: "2026-04-06T14:30:00Z",
                login: "alice",
                url: "https://github.com/acme/widget/pull/42",
                repo: "acme/widget"
            )
        ]))

        let result = try await makeService().fetchMergedPRs(
            for: [(owner: "acme", name: "widget")],
            on: Date()
        )

        let prs = try #require(result["acme/widget"])
        #expect(prs.count == 1)

        let pr = try #require(prs.first)
        #expect(pr.number == 42)
        #expect(pr.title == "Fix memory leak")
        #expect(pr.authorLogin == "alice")
        #expect(pr.url == "https://github.com/acme/widget/pull/42")
        #expect(pr.repoNameWithOwner == "acme/widget")

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let components = cal.dateComponents([.year, .month, .day, .hour], from: pr.mergedAt)
        #expect(components.year == 2026)
        #expect(components.month == 4)
        #expect(components.day == 6)
        #expect(components.hour == 14)
    }

    /// Verifies that PRs from multiple repositories are grouped under their respective `nameWithOwner` keys.
    @Test func groupsPRsByRepo() async throws {
        mockHTTP.setSuccess(json: makeResponse(nodes: [
            prNode(number: 1, title: "PR A", mergedAt: "2026-04-06T10:00:00Z", login: "alice", url: "https://github.com/acme/foo/pull/1", repo: "acme/foo"),
            prNode(number: 2, title: "PR B", mergedAt: "2026-04-06T11:00:00Z", login: "bob",   url: "https://github.com/acme/bar/pull/2", repo: "acme/bar"),
            prNode(number: 3, title: "PR C", mergedAt: "2026-04-06T12:00:00Z", login: "carol", url: "https://github.com/acme/foo/pull/3", repo: "acme/foo")
        ]))

        let result = try await makeService().fetchMergedPRs(
            for: [(owner: "acme", name: "foo"), (owner: "acme", name: "bar")],
            on: Date()
        )

        #expect(result.count == 2)
        let fooPRs = try #require(result["acme/foo"])
        #expect(fooPRs.count == 2)
        #expect(fooPRs.map(\.number).sorted() == [1, 3])

        let barPRs = try #require(result["acme/bar"])
        #expect(barPRs.count == 1)
        #expect(barPRs.first?.number == 2)
    }

    /// Verifies that PRs within a repository are sorted by `mergedAt` in ascending order.
    @Test func sortsPRsByMergedAtAscending() async throws {
        mockHTTP.setSuccess(json: makeResponse(nodes: [
            prNode(number: 10, title: "Later",   mergedAt: "2026-04-06T20:00:00Z", login: "a", url: "https://github.com/acme/repo/pull/10", repo: "acme/repo"),
            prNode(number: 1,  title: "Earlier", mergedAt: "2026-04-06T08:00:00Z", login: "b", url: "https://github.com/acme/repo/pull/1",  repo: "acme/repo")
        ]))

        let result = try await makeService().fetchMergedPRs(
            for: [(owner: "acme", name: "repo")],
            on: Date()
        )

        let prs = try #require(result["acme/repo"])
        #expect(prs.count == 2)
        #expect(prs[0].number == 1)
        #expect(prs[1].number == 10)
    }

    /// Verifies that non-PR nodes in the search results are silently filtered out.
    @Test func nonPRNodesAreFilteredOut() async throws {
        // A node with all-nil fields represents a non-PR search result (e.g. an Issue).
        let nilNode = "{}"
        mockHTTP.setSuccess(json: makeResponse(nodes: [
            nilNode,
            prNode(number: 5, title: "Real PR", mergedAt: "2026-04-06T09:00:00Z", login: "dev", url: "https://github.com/acme/repo/pull/5", repo: "acme/repo")
        ]))

        let result = try await makeService().fetchMergedPRs(
            for: [(owner: "acme", name: "repo")],
            on: Date()
        )

        let prs = try #require(result["acme/repo"])
        #expect(prs.count == 1)
        #expect(prs.first?.number == 5)
    }

    /// Verifies that the GraphQL query string includes the correct date and repo qualifiers for the given inputs.
    @Test func queryContainsCorrectDateAndRepoQualifiers() async throws {
        mockHTTP.setSuccess(json: makeResponse(nodes: []))

        // Pass a fixed date so the date string is deterministic.
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let yesterday = try #require(cal.date(from: DateComponents(year: 2026, month: 4, day: 6)))

        _ = try await makeService().fetchMergedPRs(
            for: [(owner: "acme", name: "widget")],
            on: yesterday
        )

        let bodyData = try #require(mockHTTP.lastRequest?.httpBody)
        let body = try JSONSerialization.jsonObject(with: bodyData) as! [String: Any]
        let variables = try #require(body["variables"] as? [String: Any])
        let q = try #require(variables["q"] as? String)

        #expect(q.contains("merged:2026-04-06"))
        #expect(q.contains("repo:acme/widget"))
        #expect(q.contains("is:pr"))
        #expect(q.contains("is:merged"))
    }

    /// Verifies that the query string includes a `repo:` qualifier for each repository in the input list.
    @Test func queryIncludesAllSavedRepos() async throws {
        mockHTTP.setSuccess(json: makeResponse(nodes: []))

        _ = try await makeService().fetchMergedPRs(
            for: [(owner: "acme", name: "foo"), (owner: "acme", name: "bar")],
            on: Date()
        )

        let bodyData = try #require(mockHTTP.lastRequest?.httpBody)
        let body = try JSONSerialization.jsonObject(with: bodyData) as! [String: Any]
        let variables = try #require(body["variables"] as? [String: Any])
        let q = try #require(variables["q"] as? String)

        #expect(q.contains("repo:acme/foo"))
        #expect(q.contains("repo:acme/bar"))
    }

    /// Verifies that a response with no nodes returns an empty result dictionary.
    @Test func emptyNodesReturnsEmptyDict() async throws {
        mockHTTP.setSuccess(json: makeResponse(nodes: []))

        let result = try await makeService().fetchMergedPRs(
            for: [(owner: "acme", name: "widget")],
            on: Date()
        )

        #expect(result.isEmpty)
    }

    /// Verifies that a network-level error is propagated to the caller.
    @Test func throwsOnNetworkError() async throws {
        mockHTTP.setFailure(URLError(.notConnectedToInternet))

        await #expect(throws: (any Error).self) {
            _ = try await makeService().fetchMergedPRs(
                for: [(owner: "acme", name: "widget")],
                on: Date()
            )
        }
    }

    /// Verifies that a GraphQL error response is surfaced as a `GitHubError`.
    @Test func throwsOnGraphQLError() async throws {
        mockHTTP.setSuccess(json: """
            {
              "data": null,
              "errors": [{ "message": "Something went wrong", "path": ["search"] }]
            }
            """)

        await #expect(throws: GitHubError.self) {
            _ = try await makeService().fetchMergedPRs(
                for: [(owner: "acme", name: "widget")],
                on: Date()
            )
        }
    }

    /// Verifies that all pages are fetched until the response indicates no further pages.
    @Test func fetchesAllPagesUntilHasNextPageIsFalse() async throws {
        // Page 1: two PRs, more pages available.
        mockHTTP.enqueueSuccess(json: makeResponse(
            nodes: [
                prNode(number: 1, title: "PR 1", mergedAt: "2026-04-06T08:00:00Z", login: "alice", url: "https://github.com/acme/repo/pull/1", repo: "acme/repo"),
                prNode(number: 2, title: "PR 2", mergedAt: "2026-04-06T09:00:00Z", login: "bob",   url: "https://github.com/acme/repo/pull/2", repo: "acme/repo")
            ],
            hasNextPage: true,
            endCursor: "cursor-page-2"
        ))
        // Page 2: one PR, no more pages.
        mockHTTP.enqueueSuccess(json: makeResponse(
            nodes: [
                prNode(number: 3, title: "PR 3", mergedAt: "2026-04-06T10:00:00Z", login: "carol", url: "https://github.com/acme/repo/pull/3", repo: "acme/repo")
            ],
            hasNextPage: false
        ))

        let result = try await makeService().fetchMergedPRs(
            for: [(owner: "acme", name: "repo")],
            on: Date()
        )

        let prs = try #require(result["acme/repo"])
        #expect(prs.count == 3)
        #expect(prs.map(\.number) == [1, 2, 3])
    }

    /// Verifies that the second page request includes the cursor returned by the first page.
    @Test func secondPageRequestIncludesAfterCursor() async throws {
        mockHTTP.enqueueSuccess(json: makeResponse(
            nodes: [prNode(number: 1, title: "PR 1", mergedAt: "2026-04-06T08:00:00Z", login: "alice", url: "https://github.com/acme/repo/pull/1", repo: "acme/repo")],
            hasNextPage: true,
            endCursor: "abc123"
        ))
        mockHTTP.enqueueSuccess(json: makeResponse(nodes: [], hasNextPage: false))

        _ = try await makeService().fetchMergedPRs(
            for: [(owner: "acme", name: "repo")],
            on: Date()
        )

        // lastRequest is the second page request — it must include the cursor.
        let bodyData = try #require(mockHTTP.lastRequest?.httpBody)
        let body = try JSONSerialization.jsonObject(with: bodyData) as! [String: Any]
        let variables = try #require(body["variables"] as? [String: Any])
        let after = try #require(variables["after"] as? String)
        #expect(after == "abc123")
    }
}
