import Testing
import Foundation
@testable import Focus

// MARK: - MailtoComposerTests

@Suite("MailtoComposer Tests")
struct MailtoComposerTests {

    // MARK: - url(for:)

    @Test func urlIsNilWhenNoRecipients() {
        let draft = MailtoComposer.EmailDraft(recipients: [], subject: "Test", body: "Body")
        #expect(MailtoComposer.url(for: draft) == nil)
    }

    @Test func urlSchemeIsMailto() {
        let draft = MailtoComposer.EmailDraft(recipients: ["a@example.com"], subject: "Hi", body: "Hello")
        let url = MailtoComposer.url(for: draft)
        #expect(url?.scheme == "mailto")
    }

    @Test func urlContainsSingleRecipient() {
        let draft = MailtoComposer.EmailDraft(recipients: ["alice@example.com"], subject: "Hi", body: "Hello")
        let url = MailtoComposer.url(for: draft)
        #expect(url?.absoluteString.contains("alice@example.com") == true)
    }

    @Test func urlContainsAllRecipients() {
        let draft = MailtoComposer.EmailDraft(
            recipients: ["alice@example.com", "bob@example.com"],
            subject: "Hi",
            body: "Hello"
        )
        let url = MailtoComposer.url(for: draft)
        let str = url?.absoluteString ?? ""
        #expect(str.contains("alice@example.com"))
        #expect(str.contains("bob@example.com"))
    }

    @Test func urlContainsEncodedSubject() {
        let draft = MailtoComposer.EmailDraft(recipients: ["a@b.com"], subject: "Hello World", body: "")
        let url = MailtoComposer.url(for: draft)
        #expect(url?.query?.contains("subject=Hello%20World") == true)
    }

    @Test func urlContainsBody() {
        let draft = MailtoComposer.EmailDraft(recipients: ["a@b.com"], subject: "S", body: "Some body text")
        let url = MailtoComposer.url(for: draft)
        #expect(url?.query?.contains("body=") == true)
    }

    // MARK: - draft(for:repository:recipients:)

    @Test func draftSubjectIncludesPackageAndSeverity() {
        let alert = makeAlert(packageName: "lodash", severity: "high")
        let repo = makeRepo(owner: "acme", name: "app", displayName: "acme/app")
        let draft = MailtoComposer.draft(for: alert, repository: repo, recipients: ["a@b.com"])
        #expect(draft.subject.contains("lodash"))
        #expect(draft.subject.contains("high"))
        #expect(draft.subject.contains("acme/app"))
    }

    @Test func draftBodyIncludesGHSAId() {
        let alert = makeAlert(ghsaId: "GHSA-1234-5678-abcd")
        let draft = MailtoComposer.draft(for: alert, repository: makeRepo(), recipients: ["a@b.com"])
        #expect(draft.body.contains("GHSA-1234-5678-abcd"))
    }

    @Test func draftBodyIncludesManifestPath() {
        let alert = makeAlert(manifestPath: "package-lock.json")
        let draft = MailtoComposer.draft(for: alert, repository: makeRepo(), recipients: ["a@b.com"])
        #expect(draft.body.contains("package-lock.json"))
    }

    @Test func draftBodyShowsUnknownWhenManifestPathIsNil() {
        let alert = makeAlert(manifestPath: nil)
        let draft = MailtoComposer.draft(for: alert, repository: makeRepo(), recipients: ["a@b.com"])
        #expect(draft.body.contains("unknown"))
    }

    @Test func draftBodyShowsNAWhenNoCVE() {
        let alert = makeAlert(cveId: nil)
        let draft = MailtoComposer.draft(for: alert, repository: makeRepo(), recipients: ["a@b.com"])
        #expect(draft.body.contains("N/A"))
    }

    @Test func draftBodyIncludesCVEWhenPresent() {
        let alert = makeAlert(cveId: "CVE-2024-0001")
        let draft = MailtoComposer.draft(for: alert, repository: makeRepo(), recipients: ["a@b.com"])
        #expect(draft.body.contains("CVE-2024-0001"))
    }

    @Test func draftBodyShowsNoFixAvailableWhenFixVersionIsNil() {
        let alert = makeAlert(fixVersion: nil)
        let draft = MailtoComposer.draft(for: alert, repository: makeRepo(), recipients: ["a@b.com"])
        #expect(draft.body.contains("No fix available"))
    }

    @Test func draftBodyIncludesGitHubLink() {
        let alert = makeAlert(htmlUrl: "https://github.com/acme/app/security/dependabot/1")
        let draft = MailtoComposer.draft(for: alert, repository: makeRepo(), recipients: ["a@b.com"])
        #expect(draft.body.contains("https://github.com/acme/app/security/dependabot/1"))
    }

    @Test func draftRecipientsMatchInput() {
        let recipients = ["alice@example.com", "bob@example.com"]
        let draft = MailtoComposer.draft(for: makeAlert(), repository: makeRepo(), recipients: recipients)
        #expect(draft.recipients == recipients)
    }

    // MARK: - Helpers

    private func makeAlert(
        packageName: String = "pkg",
        severity: String = "medium",
        fixVersion: String? = "1.0.1",
        ghsaId: String = "GHSA-0000-0000-0000",
        cveId: String? = "CVE-2024-0000",
        htmlUrl: String = "https://github.com/acme/app/security/dependabot/1",
        manifestPath: String? = "package.json"
    ) -> DependabotAlert {
        DependabotAlert(
            alertNumber: 1,
            packageName: packageName,
            severity: severity,
            fixVersion: fixVersion,
            createdAt: Date(),
            summary: "A summary",
            advisoryDescription: "",
            ecosystem: "npm",
            vulnerableVersionRange: "< 1.0.1",
            ghsaId: ghsaId,
            cveId: cveId,
            cvssScore: nil,
            htmlUrl: htmlUrl,
            manifestPath: manifestPath
        )
    }

    private func makeRepo(owner: String = "acme", name: String = "app", displayName: String = "acme/app") -> SavedRepository {
        SavedRepository(githubId: "1", owner: owner, name: name, displayName: displayName)
    }
}
