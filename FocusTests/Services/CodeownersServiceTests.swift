import Testing
import Foundation
import SwiftData
@testable import Focus

// MARK: - CodeownersServiceTests

@Suite("CodeownersService Tests")
@MainActor
struct CodeownersServiceTests {
    let mockHTTP = MockHTTPClient()

    private func makeService() -> CodeownersService {
        let rest = RESTClient(httpClient: mockHTTP, tokenProvider: { "test-token" })
        return CodeownersService(rest: rest)
    }

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

    // MARK: - Sync creates records

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

    @Test func syncCodeownersReturnsEmptyWhenAPIFails() async throws {
        mockHTTP.setSuccess(json: "{}", statusCode: 404)

        let container = try makeContainer()
        let context = container.mainContext
        let repo = SavedRepository(githubId: "1", owner: "acme", name: "app", displayName: "acme/app")
        context.insert(repo)

        await makeService().syncCodeowners(owner: "acme", repo: "app", repository: repo, in: context)

        #expect(repo.codeowners.isEmpty)
    }

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
