import Foundation
import Testing
import SwiftData
@testable import Focus

/// Tests for `PullRequestService`.
@Suite("PullRequestService Tests")
@MainActor // Required because sync methods are @MainActor
struct PullRequestServiceTests {
    let mockHTTP = MockHTTPClient()

    // MARK: - Setup

    /// Creates a `PullRequestService` wired to the shared `MockHTTPClient`.
    private func makeService() -> PullRequestService {
        let graphQL = GraphQLClient(httpClient: mockHTTP, tokenProvider: { "test-token" })
        return PullRequestService(graphQL: graphQL)
    }

    /// Creates an in-memory `ModelContainer` with `SavedRepository` and `OpenPullRequest` registered.
    private func makeContainer() throws -> ModelContainer { try makeTestContainer() }

    /// Builds a GraphQL-shaped JSON response string containing the given pull request stubs.
    private func makeResponse(prs: [(number: Int, title: String, createdAt: String, login: String, url: String)]) -> String {
        let nodes = prs.map { pr in
            """
            {
              "number": \(pr.number),
              "title": "\(pr.title)",
              "createdAt": "\(pr.createdAt)",
              "author": { "login": "\(pr.login)" },
              "url": "\(pr.url)"
            }
            """
        }.joined(separator: ",\n")

        return """
        {
          "data": {
            "repository": {
              "pullRequests": {
                "nodes": [\(nodes)]
              }
            }
          }
        }
        """
    }

    // MARK: - syncOpenPullRequests

    /// Verifies that a successful sync inserts one `OpenPullRequest` record per returned node.
    @Test func syncCreatesPRRecords() async throws {
        mockHTTP.setSuccess(json: makeResponse(prs: [
            (1, "Fix login bug", "2026-01-01T00:00:00Z", "alice", "https://github.com/acme/widget/pull/1"),
            (2, "Add dark mode", "2026-02-01T00:00:00Z", "bob",   "https://github.com/acme/widget/pull/2")
        ]))

        let container = try makeContainer()
        let context = container.mainContext
        let repo = SavedRepository(githubId: "1", owner: "acme", name: "widget", displayName: "Widget")
        context.insert(repo)

        await makeService().syncOpenPullRequests(owner: "acme", repo: "widget", repository: repo, in: context)

        #expect((repo.openPullRequests ?? []).count == 2)
        let numbers = Set((repo.openPullRequests ?? []).map(\.number))
        #expect(numbers == [1, 2])
    }

    /// Verifies that all scalar fields are decoded and persisted correctly from the GraphQL response.
    @Test func syncStoresFieldsCorrectly() async throws {
        mockHTTP.setSuccess(json: makeResponse(prs: [
            (42, "Refactor networking", "2026-03-15T12:00:00Z", "carol", "https://github.com/acme/widget/pull/42")
        ]))

        let container = try makeContainer()
        let context = container.mainContext
        let repo = SavedRepository(githubId: "1", owner: "acme", name: "widget", displayName: "Widget")
        context.insert(repo)

        await makeService().syncOpenPullRequests(owner: "acme", repo: "widget", repository: repo, in: context)

        let pr = try #require(repo.openPullRequests?.first)
        #expect(pr.number == 42)
        #expect(pr.title == "Refactor networking")
        #expect(pr.authorLogin == "carol")
        #expect(pr.url == "https://github.com/acme/widget/pull/42")

        // createdAt parsed from ISO8601
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let components = cal.dateComponents([.year, .month, .day], from: pr.createdAt)
        #expect(components.year == 2026)
        #expect(components.month == 3)
        #expect(components.day == 15)
    }

    /// Verifies that a second sync replaces previously persisted pull requests rather than appending.
    @Test func syncFullReplaces() async throws {
        mockHTTP.setSuccess(json: makeResponse(prs: [
            (1, "First PR", "2026-01-01T00:00:00Z", "alice", "https://github.com/acme/widget/pull/1")
        ]))

        let container = try makeContainer()
        let context = container.mainContext
        let repo = SavedRepository(githubId: "1", owner: "acme", name: "widget", displayName: "Widget")
        context.insert(repo)

        // First sync
        await makeService().syncOpenPullRequests(owner: "acme", repo: "widget", repository: repo, in: context)
        #expect((repo.openPullRequests ?? []).count == 1)

        // Second sync with different data — should replace, not accumulate
        mockHTTP.setSuccess(json: makeResponse(prs: [
            (2, "Second PR", "2026-02-01T00:00:00Z", "bob",   "https://github.com/acme/widget/pull/2"),
            (3, "Third PR",  "2026-03-01T00:00:00Z", "carol", "https://github.com/acme/widget/pull/3")
        ]))
        await makeService().syncOpenPullRequests(owner: "acme", repo: "widget", repository: repo, in: context)

        #expect((repo.openPullRequests ?? []).count == 2)
        let numbers = Set((repo.openPullRequests ?? []).map(\.number))
        #expect(numbers == [2, 3])
    }

    /// Verifies that an empty node list results in zero persisted pull requests.
    @Test func syncEmptyResponse() async throws {
        mockHTTP.setSuccess(json: makeResponse(prs: []))

        let container = try makeContainer()
        let context = container.mainContext
        let repo = SavedRepository(githubId: "1", owner: "acme", name: "widget", displayName: "Widget")
        context.insert(repo)

        await makeService().syncOpenPullRequests(owner: "acme", repo: "widget", repository: repo, in: context)

        #expect((repo.openPullRequests ?? []).isEmpty)
    }

    /// Verifies that a network error leaves previously synced pull requests untouched.
    @Test func syncSilentlyFailsOnError() async throws {
        mockHTTP.setSuccess(json: makeResponse(prs: [
            (1, "Existing PR", "2026-01-01T00:00:00Z", "alice", "https://github.com/acme/widget/pull/1")
        ]))

        let container = try makeContainer()
        let context = container.mainContext
        let repo = SavedRepository(githubId: "1", owner: "acme", name: "widget", displayName: "Widget")
        context.insert(repo)

        await makeService().syncOpenPullRequests(owner: "acme", repo: "widget", repository: repo, in: context)
        #expect((repo.openPullRequests ?? []).count == 1)

        // Simulate a network error on the second sync
        mockHTTP.setFailure(URLError(.notConnectedToInternet))
        await makeService().syncOpenPullRequests(owner: "acme", repo: "widget", repository: repo, in: context)

        // Existing record untouched
        #expect((repo.openPullRequests ?? []).count == 1)
        #expect(repo.openPullRequests?.first?.number == 1)
    }
}
