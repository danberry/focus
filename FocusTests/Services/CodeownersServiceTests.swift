import Testing
import Foundation
import SwiftData
@testable import Focus

// MARK: - CodeownersServiceTests

/// Tests for `CodeownersService`.
@Suite("CodeownersService Tests")
@MainActor // Required because syncCodeowners is @MainActor
struct CodeownersServiceTests {
    let mockHTTP = MockHTTPClient()

    // MARK: - Setup

    /// Creates a `CodeownersService` wired to the shared `MockHTTPClient`.
    private func makeService() -> CodeownersService {
        let rest = RESTClient(httpClient: mockHTTP, tokenProvider: { "test-token" })
        return CodeownersService(rest: rest)
    }

    /// Creates an in-memory `ModelContainer` with the relevant model types registered.
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: SavedRepository.self, configurations: config)
    }

    /// Encodes a CODEOWNERS file content as a GitHub Contents API JSON response.
    private func contentsResponse(for codeownersText: String) -> String {
        let base64 = Data(codeownersText.utf8).base64EncodedString()
        return """
        {"type":"file","encoding":"base64","content":"\(base64)"}
        """
    }

    // MARK: - syncCodeowners

    /// Verifies that syncing a CODEOWNERS file creates one record per unique owner handle.
    @Test func syncCodeownersCreatesRecords() async throws {
        let content = """
        * @alice @bob
        *.swift @alice
        """
        mockHTTP.setSuccess(json: contentsResponse(for: content))

        let container = try makeContainer()
        let context = container.mainContext
        let repo = SavedRepository(githubId: "1", owner: "acme", name: "app", displayName: "acme/app")
        context.insert(repo)

        await makeService().syncCodeowners(owner: "acme", repo: "app", repository: repo, in: context)

        let handles = repo.codeowners.map(\.handle).sorted()
        #expect(handles.count == 3)
        #expect(handles.contains("@alice"))
        #expect(handles.contains("@bob"))
    }

    /// Verifies that the path pattern from each CODEOWNERS line is stored on the record.
    @Test func syncCodeownersPreservesPatterns() async throws {
        let content = "*.swift @alice\n"
        mockHTTP.setSuccess(json: contentsResponse(for: content))

        let container = try makeContainer()
        let context = container.mainContext
        let repo = SavedRepository(githubId: "1", owner: "acme", name: "app", displayName: "acme/app")
        context.insert(repo)

        await makeService().syncCodeowners(owner: "acme", repo: "app", repository: repo, in: context)

        let codeowner = try #require(repo.codeowners.first)
        #expect(codeowner.handle == "@alice")
        #expect(codeowner.pathPattern == "*.swift")
    }

    /// Verifies that comment lines in a CODEOWNERS file are skipped and produce no records.
    @Test func syncCodeownersIgnoresCommentLines() async throws {
        let content = """
        # This is a comment
        * @alice
        # Another comment
        """
        mockHTTP.setSuccess(json: contentsResponse(for: content))

        let container = try makeContainer()
        let context = container.mainContext
        let repo = SavedRepository(githubId: "1", owner: "acme", name: "app", displayName: "acme/app")
        context.insert(repo)

        await makeService().syncCodeowners(owner: "acme", repo: "app", repository: repo, in: context)

        #expect(repo.codeowners.count == 1)
        #expect(repo.codeowners[0].handle == "@alice")
    }

    /// Verifies that a second sync replaces previously persisted codeowners rather than appending.
    @Test func syncCodeownersReplacesExistingRecords() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let repo = SavedRepository(githubId: "1", owner: "acme", name: "app", displayName: "acme/app")
        context.insert(repo)

        // Insert a stale codeowner
        let stale = Codeowner(handle: "@old-owner", pathPattern: "*")
        stale.repository = repo
        context.insert(stale)
        try context.save()
        #expect(repo.codeowners.count == 1)

        // Now sync with new content
        mockHTTP.setSuccess(json: contentsResponse(for: "* @new-owner\n"))
        await makeService().syncCodeowners(owner: "acme", repo: "app", repository: repo, in: context)

        #expect(repo.codeowners.count == 1)
        #expect(repo.codeowners[0].handle == "@new-owner")
    }

    /// Verifies that a non-2xx API response leaves the repository's codeowners list empty.
    @Test func syncCodeownersReturnsEmptyWhenAPIFails() async throws {
        mockHTTP.setSuccess(json: "{}", statusCode: 404)

        let container = try makeContainer()
        let context = container.mainContext
        let repo = SavedRepository(githubId: "1", owner: "acme", name: "app", displayName: "acme/app")
        context.insert(repo)

        await makeService().syncCodeowners(owner: "acme", repo: "app", repository: repo, in: context)

        #expect(repo.codeowners.isEmpty)
    }

    /// Verifies that the request targets the GitHub Contents API path for the repository.
    @Test func syncCodeownersUsesCorrectEndpoint() async throws {
        mockHTTP.setSuccess(json: contentsResponse(for: "* @alice\n"))

        let container = try makeContainer()
        let context = container.mainContext
        let repo = SavedRepository(githubId: "1", owner: "octocat", name: "hello-world", displayName: "hello-world")
        context.insert(repo)

        await makeService().syncCodeowners(owner: "octocat", repo: "hello-world", repository: repo, in: context)

        let path = mockHTTP.lastRequest?.url?.path ?? ""
        #expect(path.hasPrefix("/repos/octocat/hello-world/contents/"))
    }

    /// Verifies that a team slug (org/team format) is stored correctly and flagged as a team owner.
    @Test func syncCodeownersHandlesTeamOwners() async throws {
        mockHTTP.setSuccess(json: contentsResponse(for: "* @acme/engineers\n"))

        let container = try makeContainer()
        let context = container.mainContext
        let repo = SavedRepository(githubId: "1", owner: "acme", name: "app", displayName: "acme/app")
        context.insert(repo)

        await makeService().syncCodeowners(owner: "acme", repo: "app", repository: repo, in: context)

        let codeowner = try #require(repo.codeowners.first)
        #expect(codeowner.handle == "@acme/engineers")
        #expect(codeowner.isTeam == true)
    }

    /// Verifies that each synced codeowner record has its repository relationship set.
    @Test func syncCodeownersSetsSetsRepositoryRelationship() async throws {
        mockHTTP.setSuccess(json: contentsResponse(for: "* @alice\n"))

        let container = try makeContainer()
        let context = container.mainContext
        let repo = SavedRepository(githubId: "1", owner: "acme", name: "app", displayName: "acme/app")
        context.insert(repo)

        await makeService().syncCodeowners(owner: "acme", repo: "app", repository: repo, in: context)

        let codeowner = try #require(repo.codeowners.first)
        #expect(codeowner.repository === repo)
    }

    /// Verifies that a line with only a handle and no explicit pattern defaults to the wildcard pattern.
    @Test func syncCodeownersHandlesHandleWithNoPattern() async throws {
        // CODEOWNERS file with only a handle and no explicit path pattern
        let content = "@acme/mobile-team\n"
        mockHTTP.setSuccess(json: contentsResponse(for: content))

        let container = try makeContainer()
        let context = container.mainContext
        let repo = SavedRepository(githubId: "1", owner: "acme", name: "app", displayName: "acme/app")
        context.insert(repo)

        await makeService().syncCodeowners(owner: "acme", repo: "app", repository: repo, in: context)

        let codeowner = try #require(repo.codeowners.first)
        #expect(codeowner.handle == "@acme/mobile-team")
        #expect(codeowner.pathPattern == "*")
        #expect(codeowner.isTeam == true)
    }

    /// Verifies that a line with only a path pattern and no owner handles produces no records.
    @Test func syncCodeownersHandlesPatternWithoutOwners() async throws {
        // A line with only a path pattern and no @ handles should produce no records
        let content = """
        docs/
        * @alice
        """
        mockHTTP.setSuccess(json: contentsResponse(for: content))

        let container = try makeContainer()
        let context = container.mainContext
        let repo = SavedRepository(githubId: "1", owner: "acme", name: "app", displayName: "acme/app")
        context.insert(repo)

        await makeService().syncCodeowners(owner: "acme", repo: "app", repository: repo, in: context)

        // Only the "* @alice" line produces a record
        #expect(repo.codeowners.count == 1)
        #expect(repo.codeowners[0].handle == "@alice")
    }
}
