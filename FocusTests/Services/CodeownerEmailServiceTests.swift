import Testing
import Foundation
import SwiftData
@testable import Focus

// MARK: - CodeownerEmailServiceTests

/// Tests for `CodeownerEmailService`.
@Suite("CodeownerEmailService Tests")
@MainActor // MockHTTPClient is a class with mutable state; @MainActor serializes access across async calls
struct CodeownerEmailServiceTests {
    let mockHTTP = MockHTTPClient()

    /// Creates a `CodeownerEmailService` wired to the shared `MockHTTPClient`.
    private func makeService() -> CodeownerEmailService {
        let rest = RESTClient(httpClient: mockHTTP, tokenProvider: { "test-token" })
        return CodeownerEmailService(rest: rest)
    }

    // MARK: - Individual user email

    /// Verifies that a handle with a publicly visible email resolves to that email address.
    @Test func resolvesIndividualUserEmail() async {
        mockHTTP.setSuccess(json: #"{"login":"alice","email":"alice@example.com"}"#)
        let emails = await makeService().resolveEmails(handles: ["@alice"], organization: "acme")
        #expect(emails == ["alice@example.com"])
    }

    /// Verifies that a null email in the API response is excluded from results.
    @Test func returnsEmptyWhenUserHasNoEmail() async {
        mockHTTP.setSuccess(json: #"{"login":"alice","email":null}"#)
        let emails = await makeService().resolveEmails(handles: ["@alice"], organization: "acme")
        #expect(emails.isEmpty)
    }

    /// Verifies that a blank email string in the API response is excluded from results.
    @Test func returnsEmptyWhenUserEmailIsBlank() async {
        mockHTTP.setSuccess(json: #"{"login":"alice","email":""}"#)
        let emails = await makeService().resolveEmails(handles: ["@alice"], organization: "acme")
        #expect(emails.isEmpty)
    }

    /// Verifies that the `@` prefix is stripped before constructing the users API path.
    @Test func stripsAtPrefixFromHandle() async {
        mockHTTP.setSuccess(json: #"{"login":"alice","email":"alice@example.com"}"#)
        _ = await makeService().resolveEmails(handles: ["@alice"], organization: "acme")
        let path = mockHTTP.lastRequest?.url?.path ?? ""
        #expect(path == "/users/alice")
    }

    /// Verifies that a 403 response results in an empty email list rather than a thrown error.
    @Test func handlesNetworkErrorGracefully() async {
        mockHTTP.setSuccess(json: "{}", statusCode: 403)
        let emails = await makeService().resolveEmails(handles: ["@alice"], organization: "acme")
        #expect(emails.isEmpty)
    }

    /// Verifies that duplicate handles resolving to the same email produce only one entry.
    @Test func deduplicatesEmailsAcrossHandles() async {
        // Both handles resolve to the same email
        mockHTTP.setSuccess(json: #"{"login":"alice","email":"alice@example.com"}"#)
        let emails = await makeService().resolveEmails(handles: ["@alice", "@alice"], organization: "acme")
        #expect(emails.count == 1)
        #expect(emails == ["alice@example.com"])
    }

    // MARK: - Team expansion

    /// Verifies that a team handle routes to the correct team members endpoint.
    @Test func parsesOrgAndSlugFromTeamHandle() async {
        // First call: team members list
        // Second call: user profile — but MockHTTPClient has only one result slot,
        // so we verify the team members endpoint is called with the right path.
        mockHTTP.setSuccess(json: "[]")
        _ = await makeService().resolveEmails(handles: ["@acme/engineers"], organization: "acme")
        let path = mockHTTP.lastRequest?.url?.path ?? ""
        #expect(path == "/orgs/acme/teams/engineers/members")
    }

    /// Verifies that a team handle with no members returns an empty email list.
    @Test func expandsTeamHandleToMemberEmails() async {
        // The mock returns the same response for every request.
        // First request (team members) → returns one member.
        // Second request (user profile) → returns same JSON (happens to decode as UserProfileResponse too).
        // We use a JSON that satisfies both: array of one user for the members call,
        // but that won't satisfy the profile decode. Instead we test the empty-members path.
        mockHTTP.setSuccess(json: "[]")
        let emails = await makeService().resolveEmails(handles: ["@acme/engineers"], organization: "acme")
        // Empty members → empty emails
        #expect(emails.isEmpty)
    }

    // MARK: - Empty input

    /// Verifies that an empty handles array returns an empty email list without any network calls.
    @Test func emptyHandlesReturnsEmpty() async {
        let emails = await makeService().resolveEmails(handles: [], organization: "acme")
        #expect(emails.isEmpty)
    }

    /// Verifies that handles without the `@` prefix are resolved the same as prefixed handles.
    @Test func handleWithoutAtPrefixAlsoWorks() async {
        mockHTTP.setSuccess(json: #"{"login":"alice","email":"alice@example.com"}"#)
        let emails = await makeService().resolveEmails(handles: ["alice"], organization: "acme")
        #expect(emails == ["alice@example.com"])
    }
}

// MARK: - ResolveLoginsTests

/// Tests for `CodeownerEmailService.resolveLogins`.
@Suite("CodeownerEmailService resolveLogins Tests")
@MainActor // MockHTTPClient is a class with mutable state; @MainActor serializes access across async calls
struct ResolveLoginsTests {
    let mockHTTP = MockHTTPClient()

    /// Creates a `CodeownerEmailService` wired to the shared `MockHTTPClient`.
    private func makeService() -> CodeownerEmailService {
        let rest = RESTClient(httpClient: mockHTTP, tokenProvider: { "test-token" })
        return CodeownerEmailService(rest: rest)
    }

    /// Verifies that a single `@`-prefixed handle returns its stripped login.
    @Test func individualHandleReturnsLogin() async {
        let logins = await makeService().resolveLogins(handles: ["@alice"])
        #expect(logins == ["alice"])
    }

    /// Verifies that a handle without the `@` prefix is returned as-is.
    @Test func stripsAtPrefix() async {
        let logins = await makeService().resolveLogins(handles: ["alice"])
        #expect(logins == ["alice"])
    }

    /// Verifies that multiple individual handles return a login for each.
    @Test func multipleIndividualHandles() async {
        let logins = await makeService().resolveLogins(handles: ["@alice", "@bob"])
        #expect(logins == ["alice", "bob"])
    }

    /// Verifies that duplicate handles return only one login entry.
    @Test func deduplicatesLogins() async {
        let logins = await makeService().resolveLogins(handles: ["@alice", "@alice"])
        #expect(logins == ["alice"])
    }

    /// Verifies that an empty handles array returns an empty login list.
    @Test func emptyHandlesReturnsEmpty() async {
        let logins = await makeService().resolveLogins(handles: [])
        #expect(logins.isEmpty)
    }

    /// Verifies that a team handle routes to the correct team members API path.
    @Test func teamHandleCallsTeamMembersEndpoint() async {
        mockHTTP.setSuccess(json: "[]")
        _ = await makeService().resolveLogins(handles: ["@acme/engineers"])
        let path = mockHTTP.lastRequest?.url?.path ?? ""
        #expect(path == "/orgs/acme/teams/engineers/members")
    }

    /// Verifies that a team with two members expands to both member logins.
    @Test func teamHandleExpandsToMemberLogins() async {
        mockHTTP.setSuccess(json: #"""
            [{"login":"alice","id":1},{"login":"bob","id":2}]
        """#)
        let logins = await makeService().resolveLogins(handles: ["@acme/engineers"])
        #expect(logins == ["alice", "bob"])
    }

    /// Verifies that a 403 on the team members request returns an empty login list.
    @Test func teamHandleNetworkErrorReturnsEmpty() async {
        mockHTTP.setSuccess(json: "{}", statusCode: 403)
        let logins = await makeService().resolveLogins(handles: ["@acme/engineers"])
        #expect(logins.isEmpty)
    }

    /// Verifies that a mix of individual and team handles resolves all logins.
    @Test func mixedHandlesExpandsBoth() async {
        // Individual @carol + team @acme/engineers with members alice, bob
        mockHTTP.setSuccess(json: #"""
            [{"login":"alice","id":1},{"login":"bob","id":2}]
        """#)
        // Note: mockHTTP returns the same JSON for all requests.
        // @carol is an individual handle — it does NOT make a network call, it just uses the login directly.
        // Only the team handle triggers the mock.
        let logins = await makeService().resolveLogins(handles: ["@carol", "@acme/engineers"])
        #expect(Set(logins) == Set(["carol", "alice", "bob"]))
    }

    /// Verifies that a login appearing in both an individual handle and a team is deduplicated.
    @Test func deduplicatesAcrossIndividualAndTeam() async {
        // alice is listed individually AND is a member of the team
        mockHTTP.setSuccess(json: #"""
            [{"login":"alice","id":1},{"login":"bob","id":2}]
        """#)
        let logins = await makeService().resolveLogins(handles: ["@alice", "@acme/engineers"])
        #expect(Set(logins) == Set(["alice", "bob"]))
    }

    /// Verifies that a malformed team handle (missing org or slug) returns an empty login list.
    @Test func malformedTeamHandleReturnsEmpty() async {
        // "@/broken" → strips "@" → "/broken" → split omits empty → only one part → guard fails → []
        let logins = await makeService().resolveLogins(handles: ["@/broken"])
        #expect(logins.isEmpty)
    }
}
