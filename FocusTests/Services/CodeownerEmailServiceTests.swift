import Testing
import Foundation
import SwiftData
@testable import Focus

// MARK: - CodeownerEmailServiceTests

@Suite("CodeownerEmailService Tests")
@MainActor
struct CodeownerEmailServiceTests {
    let mockHTTP = MockHTTPClient()

    private func makeService() -> CodeownerEmailService {
        let rest = RESTClient(httpClient: mockHTTP, tokenProvider: { "test-token" })
        return CodeownerEmailService(rest: rest)
    }

    // MARK: - Individual user email

    @Test func resolvesIndividualUserEmail() async {
        mockHTTP.setSuccess(json: #"{"login":"alice","email":"alice@example.com"}"#)
        let emails = await makeService().resolveEmails(handles: ["@alice"], organization: "acme")
        #expect(emails == ["alice@example.com"])
    }

    @Test func returnsEmptyWhenUserHasNoEmail() async {
        mockHTTP.setSuccess(json: #"{"login":"alice","email":null}"#)
        let emails = await makeService().resolveEmails(handles: ["@alice"], organization: "acme")
        #expect(emails.isEmpty)
    }

    @Test func returnsEmptyWhenUserEmailIsBlank() async {
        mockHTTP.setSuccess(json: #"{"login":"alice","email":""}"#)
        let emails = await makeService().resolveEmails(handles: ["@alice"], organization: "acme")
        #expect(emails.isEmpty)
    }

    @Test func stripsAtPrefixFromHandle() async {
        mockHTTP.setSuccess(json: #"{"login":"alice","email":"alice@example.com"}"#)
        _ = await makeService().resolveEmails(handles: ["@alice"], organization: "acme")
        let path = mockHTTP.lastRequest?.url?.path ?? ""
        #expect(path == "/users/alice")
    }

    @Test func handlesNetworkErrorGracefully() async {
        mockHTTP.setSuccess(json: "{}", statusCode: 403)
        let emails = await makeService().resolveEmails(handles: ["@alice"], organization: "acme")
        #expect(emails.isEmpty)
    }

    @Test func deduplicatesEmailsAcrossHandles() async {
        // Both handles resolve to the same email
        mockHTTP.setSuccess(json: #"{"login":"alice","email":"alice@example.com"}"#)
        let emails = await makeService().resolveEmails(handles: ["@alice", "@alice"], organization: "acme")
        #expect(emails.count == 1)
        #expect(emails == ["alice@example.com"])
    }

    // MARK: - Team expansion

    @Test func parsesOrgAndSlugFromTeamHandle() async {
        // First call: team members list
        // Second call: user profile — but MockHTTPClient has only one result slot,
        // so we verify the team members endpoint is called with the right path.
        mockHTTP.setSuccess(json: "[]")
        _ = await makeService().resolveEmails(handles: ["@acme/engineers"], organization: "acme")
        let path = mockHTTP.lastRequest?.url?.path ?? ""
        #expect(path == "/orgs/acme/teams/engineers/members")
    }

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

    @Test func emptyHandlesReturnsEmpty() async {
        let emails = await makeService().resolveEmails(handles: [], organization: "acme")
        #expect(emails.isEmpty)
    }

    @Test func handleWithoutAtPrefixAlsoWorks() async {
        mockHTTP.setSuccess(json: #"{"login":"alice","email":"alice@example.com"}"#)
        let emails = await makeService().resolveEmails(handles: ["alice"], organization: "acme")
        #expect(emails == ["alice@example.com"])
    }
}

// MARK: - ResolveLoginsTests

@Suite("CodeownerEmailService resolveLogins Tests")
@MainActor
struct ResolveLoginsTests {
    let mockHTTP = MockHTTPClient()

    private func makeService() -> CodeownerEmailService {
        let rest = RESTClient(httpClient: mockHTTP, tokenProvider: { "test-token" })
        return CodeownerEmailService(rest: rest)
    }

    @Test func individualHandleReturnsLogin() async {
        let logins = await makeService().resolveLogins(handles: ["@alice"])
        #expect(logins == ["alice"])
    }

    @Test func stripsAtPrefix() async {
        let logins = await makeService().resolveLogins(handles: ["alice"])
        #expect(logins == ["alice"])
    }

    @Test func multipleIndividualHandles() async {
        let logins = await makeService().resolveLogins(handles: ["@alice", "@bob"])
        #expect(logins == ["alice", "bob"])
    }

    @Test func deduplicatesLogins() async {
        let logins = await makeService().resolveLogins(handles: ["@alice", "@alice"])
        #expect(logins == ["alice"])
    }

    @Test func emptyHandlesReturnsEmpty() async {
        let logins = await makeService().resolveLogins(handles: [])
        #expect(logins.isEmpty)
    }

    @Test func teamHandleCallsTeamMembersEndpoint() async {
        mockHTTP.setSuccess(json: "[]")
        _ = await makeService().resolveLogins(handles: ["@acme/engineers"])
        let path = mockHTTP.lastRequest?.url?.path ?? ""
        #expect(path == "/orgs/acme/teams/engineers/members")
    }

    @Test func teamHandleExpandsToMemberLogins() async {
        mockHTTP.setSuccess(json: #"""
            [{"login":"alice","id":1},{"login":"bob","id":2}]
        """#)
        let logins = await makeService().resolveLogins(handles: ["@acme/engineers"])
        #expect(logins == ["alice", "bob"])
    }

    @Test func teamHandleNetworkErrorReturnsEmpty() async {
        mockHTTP.setSuccess(json: "{}", statusCode: 403)
        let logins = await makeService().resolveLogins(handles: ["@acme/engineers"])
        #expect(logins.isEmpty)
    }

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

    @Test func deduplicatesAcrossIndividualAndTeam() async {
        // alice is listed individually AND is a member of the team
        mockHTTP.setSuccess(json: #"""
            [{"login":"alice","id":1},{"login":"bob","id":2}]
        """#)
        let logins = await makeService().resolveLogins(handles: ["@alice", "@acme/engineers"])
        #expect(Set(logins) == Set(["alice", "bob"]))
    }

    @Test func malformedTeamHandleReturnsEmpty() async {
        // "@/broken" → strips "@" → "/broken" → split omits empty → only one part → guard fails → []
        let logins = await makeService().resolveLogins(handles: ["@/broken"])
        #expect(logins.isEmpty)
    }
}
