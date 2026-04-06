import Foundation
import Testing
import SwiftData
@testable import Focus

@Suite("PullRequestService Tests")
@MainActor
struct PullRequestServiceTests {
    let mockHTTP = MockHTTPClient()

    private func makeService() -> PullRequestService {
        let graphQL = GraphQLClient(httpClient: mockHTTP, tokenProvider: { "test-token" })
        return PullRequestService(graphQL: graphQL)
    }

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: SavedRepository.self, OpenPullRequest.self,
            configurations: config
        )
    }

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

    // MARK: - Successful fetch inserts records

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

        #expect(repo.openPullRequests.count == 2)
        let numbers = Set(repo.openPullRequests.map(\.number))
        #expect(numbers == [1, 2])
    }

    // MARK: - Fields are stored correctly

    @Test func syncStoresFieldsCorrectly() async throws {
        mockHTTP.setSuccess(json: makeResponse(prs: [
            (42, "Refactor networking", "2026-03-15T12:00:00Z", "carol", "https://github.com/acme/widget/pull/42")
        ]))

        let container = try makeContainer()
        let context = container.mainContext
        let repo = SavedRepository(githubId: "1", owner: "acme", name: "widget", displayName: "Widget")
        context.insert(repo)

        await makeService().syncOpenPullRequests(owner: "acme", repo: "widget", repository: repo, in: context)

        let pr = try #require(repo.openPullRequests.first)
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

    // MARK: - Full-replace sync

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
        #expect(repo.openPullRequests.count == 1)

        // Second sync with different data — should replace, not accumulate
        mockHTTP.setSuccess(json: makeResponse(prs: [
            (2, "Second PR", "2026-02-01T00:00:00Z", "bob",   "https://github.com/acme/widget/pull/2"),
            (3, "Third PR",  "2026-03-01T00:00:00Z", "carol", "https://github.com/acme/widget/pull/3")
        ]))
        await makeService().syncOpenPullRequests(owner: "acme", repo: "widget", repository: repo, in: context)

        #expect(repo.openPullRequests.count == 2)
        let numbers = Set(repo.openPullRequests.map(\.number))
        #expect(numbers == [2, 3])
    }

    // MARK: - Empty response

    @Test func syncEmptyResponse() async throws {
        mockHTTP.setSuccess(json: makeResponse(prs: []))

        let container = try makeContainer()
        let context = container.mainContext
        let repo = SavedRepository(githubId: "1", owner: "acme", name: "widget", displayName: "Widget")
        context.insert(repo)

        await makeService().syncOpenPullRequests(owner: "acme", repo: "widget", repository: repo, in: context)

        #expect(repo.openPullRequests.isEmpty)
    }

    // MARK: - Silent failure preserves existing data

    @Test func syncSilentlyFailsOnError() async throws {
        mockHTTP.setSuccess(json: makeResponse(prs: [
            (1, "Existing PR", "2026-01-01T00:00:00Z", "alice", "https://github.com/acme/widget/pull/1")
        ]))

        let container = try makeContainer()
        let context = container.mainContext
        let repo = SavedRepository(githubId: "1", owner: "acme", name: "widget", displayName: "Widget")
        context.insert(repo)

        await makeService().syncOpenPullRequests(owner: "acme", repo: "widget", repository: repo, in: context)
        #expect(repo.openPullRequests.count == 1)

        // Simulate a network error on the second sync
        mockHTTP.setFailure(URLError(.notConnectedToInternet))
        await makeService().syncOpenPullRequests(owner: "acme", repo: "widget", repository: repo, in: context)

        // Existing record untouched
        #expect(repo.openPullRequests.count == 1)
        #expect(repo.openPullRequests.first?.number == 1)
    }
}
