import Foundation
import Testing
import SwiftData
@testable import Focus

/// Tests for `BranchService`.
@Suite("BranchService Tests")
@MainActor // Required because sync methods are @MainActor
struct BranchServiceTests {

    let mockHTTP = MockHTTPClient()

    // MARK: - Setup

    /// Creates a `BranchService` wired to the shared `MockHTTPClient`.
    private func makeService() -> BranchService {
        let graphQL = GraphQLClient(httpClient: mockHTTP, tokenProvider: { "test-token" })
        return BranchService(graphQL: graphQL)
    }

    /// Creates an in-memory `ModelContainer` with `SavedRepository` and `SavedBranch` registered.
    private func makeContainer() throws -> ModelContainer { try makeTestContainer() }

    /// Builds a GraphQL-shaped JSON response string for the given branch stubs.
    private func makeResponse(
        defaultBranch: String?,
        branches: [(name: String, committedDate: String)]
    ) -> String {
        let defaultRef = defaultBranch.map { "{ \"name\": \"\($0)\" }" } ?? "null"
        let nodes = branches.map { branch in
            """
            {
              "name": "\(branch.name)",
              "target": { "committedDate": "\(branch.committedDate)" }
            }
            """
        }.joined(separator: ",\n")

        return """
        {
          "data": {
            "repository": {
              "defaultBranchRef": \(defaultRef),
              "refs": {
                "nodes": [\(nodes)]
              }
            }
          }
        }
        """
    }

    // MARK: - syncBranches

    /// Verifies that a successful sync inserts one `SavedBranch` record per returned node.
    @Test func syncCreatesBranchRecords() async throws {
        mockHTTP.setSuccess(json: makeResponse(
            defaultBranch: "main",
            branches: [
                ("main",              "2026-05-20T10:00:00Z"),
                ("feature/payments", "2026-05-18T08:00:00Z")
            ]
        ))

        let container = try makeContainer()
        let context = container.mainContext
        let repo = SavedRepository(githubId: "1", owner: "acme", name: "widget", displayName: "Widget")
        context.insert(repo)

        await makeService().syncBranches(owner: "acme", repo: "widget", repository: repo, in: context)

        #expect((repo.branches ?? []).count == 2)
        let names = Set((repo.branches ?? []).map(\.name))
        #expect(names == ["main", "feature/payments"])
    }

    /// Verifies that all scalar fields are decoded and persisted correctly.
    @Test func syncStoresFieldsCorrectly() async throws {
        mockHTTP.setSuccess(json: makeResponse(
            defaultBranch: "main",
            branches: [("main", "2026-03-15T12:00:00Z")]
        ))

        let container = try makeContainer()
        let context = container.mainContext
        let repo = SavedRepository(githubId: "1", owner: "acme", name: "widget", displayName: "Widget")
        context.insert(repo)

        await makeService().syncBranches(owner: "acme", repo: "widget", repository: repo, in: context)

        let branch = try #require(repo.branches?.first)
        #expect(branch.name == "main")
        #expect(branch.isDefault == true)

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let components = cal.dateComponents([.year, .month, .day], from: branch.pushedAt)
        #expect(components.year == 2026)
        #expect(components.month == 3)
        #expect(components.day == 15)
    }

    /// Verifies that the `isDefault` flag is set only on the branch matching `defaultBranchRef.name`.
    @Test func syncMarksOnlyDefaultBranch() async throws {
        mockHTTP.setSuccess(json: makeResponse(
            defaultBranch: "main",
            branches: [
                ("main",             "2026-05-20T10:00:00Z"),
                ("feature/new-ui",  "2026-05-19T09:00:00Z"),
                ("release/1.0",     "2026-05-01T08:00:00Z")
            ]
        ))

        let container = try makeContainer()
        let context = container.mainContext
        let repo = SavedRepository(githubId: "1", owner: "acme", name: "widget", displayName: "Widget")
        context.insert(repo)

        await makeService().syncBranches(owner: "acme", repo: "widget", repository: repo, in: context)

        let branches = repo.branches ?? []
        let defaultBranches = branches.filter(\.isDefault)
        #expect(defaultBranches.count == 1)
        #expect(defaultBranches.first?.name == "main")
        #expect(branches.filter { !$0.isDefault }.count == 2)
    }

    /// Verifies that a second sync replaces previously persisted branches rather than appending.
    @Test func syncFullReplaces() async throws {
        mockHTTP.setSuccess(json: makeResponse(
            defaultBranch: "main",
            branches: [("main", "2026-05-20T10:00:00Z")]
        ))

        let container = try makeContainer()
        let context = container.mainContext
        let repo = SavedRepository(githubId: "1", owner: "acme", name: "widget", displayName: "Widget")
        context.insert(repo)

        await makeService().syncBranches(owner: "acme", repo: "widget", repository: repo, in: context)
        #expect((repo.branches ?? []).count == 1)

        mockHTTP.setSuccess(json: makeResponse(
            defaultBranch: "main",
            branches: [
                ("main",            "2026-05-20T10:00:00Z"),
                ("feature/dark-mode", "2026-05-19T08:00:00Z"),
                ("fix/login",       "2026-05-18T07:00:00Z")
            ]
        ))
        await makeService().syncBranches(owner: "acme", repo: "widget", repository: repo, in: context)

        #expect((repo.branches ?? []).count == 3)
    }

    /// Verifies that an empty node list results in zero persisted branches.
    @Test func syncEmptyResponse() async throws {
        mockHTTP.setSuccess(json: makeResponse(defaultBranch: "main", branches: []))

        let container = try makeContainer()
        let context = container.mainContext
        let repo = SavedRepository(githubId: "1", owner: "acme", name: "widget", displayName: "Widget")
        context.insert(repo)

        await makeService().syncBranches(owner: "acme", repo: "widget", repository: repo, in: context)

        #expect((repo.branches ?? []).isEmpty)
    }

    /// Verifies that a `null` `defaultBranchRef` results in no branch being marked as default.
    @Test func syncNoDefaultBranchRef() async throws {
        mockHTTP.setSuccess(json: makeResponse(
            defaultBranch: nil,
            branches: [("main", "2026-05-20T10:00:00Z")]
        ))

        let container = try makeContainer()
        let context = container.mainContext
        let repo = SavedRepository(githubId: "1", owner: "acme", name: "widget", displayName: "Widget")
        context.insert(repo)

        await makeService().syncBranches(owner: "acme", repo: "widget", repository: repo, in: context)

        #expect((repo.branches ?? []).filter(\.isDefault).isEmpty)
    }

    /// Verifies that a network error leaves previously synced branches untouched.
    @Test func syncSilentlyFailsOnError() async throws {
        mockHTTP.setSuccess(json: makeResponse(
            defaultBranch: "main",
            branches: [("main", "2026-05-20T10:00:00Z")]
        ))

        let container = try makeContainer()
        let context = container.mainContext
        let repo = SavedRepository(githubId: "1", owner: "acme", name: "widget", displayName: "Widget")
        context.insert(repo)

        await makeService().syncBranches(owner: "acme", repo: "widget", repository: repo, in: context)
        #expect((repo.branches ?? []).count == 1)

        mockHTTP.setFailure(URLError(.notConnectedToInternet))
        await makeService().syncBranches(owner: "acme", repo: "widget", repository: repo, in: context)

        #expect((repo.branches ?? []).count == 1)
        #expect(repo.branches?.first?.name == "main")
    }
}
