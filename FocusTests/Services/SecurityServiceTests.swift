import Foundation
import Testing
import SwiftData
@testable import Focus

/// Tests for ``SecurityService``.
@Suite("SecurityService Tests")
@MainActor // Required because sync methods write to a @MainActor ModelContext
struct SecurityServiceTests {
    let mockHTTP = MockHTTPClient()

    // MARK: - Setup

    /// Creates a ``SecurityService`` wired to the shared ``MockHTTPClient``.
    private func makeService() -> SecurityService {
        let rest = RESTClient(httpClient: mockHTTP, tokenProvider: { "test-token" })
        return SecurityService(rest: rest)
    }

    /// Creates an in-memory ``ModelContainer`` with the alert model types registered.
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: SavedRepository.self, DependabotAlert.self, CodeScanningAlert.self, SecretScanningAlert.self,
            Team.self, Department.self, SavedOrganization.self,
            configurations: config
        )
    }

    // MARK: - fetchMetrics

    /// Verifies that a 2-item array response yields a count of 2 for all three alert types.
    @Test func fetchMetricsReturnsCorrectCounts() async {
        // MockHTTPClient returns the same response for every call.
        // All three endpoints return an array of 2 items.
        mockHTTP.setSuccess(json: "[{}, {}]")
        let metrics = await makeService().fetchMetrics(owner: "apple", repo: "swift")

        #expect(metrics.dependabotAlerts == 2)
        #expect(metrics.codeScanningAlerts == 2)
        #expect(metrics.secretScanningAlerts == 2)
    }

    /// Verifies that a 403 response causes all three counts to be returned as `nil`.
    @Test func fetchMetricsHandlesForbidden() async {
        mockHTTP.setSuccess(json: "{}", statusCode: 403)
        let metrics = await makeService().fetchMetrics(owner: "apple", repo: "swift")

        #expect(metrics.dependabotAlerts == nil)
        #expect(metrics.codeScanningAlerts == nil)
        #expect(metrics.secretScanningAlerts == nil)
    }

    /// Verifies that a 404 response causes all three counts to be returned as `nil`.
    @Test func fetchMetricsHandlesNotFound() async {
        mockHTTP.setSuccess(json: "{}", statusCode: 404)
        let metrics = await makeService().fetchMetrics(owner: "apple", repo: "swift")

        #expect(metrics.dependabotAlerts == nil)
        #expect(metrics.codeScanningAlerts == nil)
        #expect(metrics.secretScanningAlerts == nil)
    }

    /// Verifies that the request targets `api.github.com` with the expected repository path prefix.
    @Test func fetchMetricsUsesCorrectPath() async {
        mockHTTP.setSuccess(json: "[]")
        _ = await makeService().fetchMetrics(owner: "octocat", repo: "hello-world")

        // lastRequest reflects one of the three parallel calls; verify it targets the expected host and prefix
        let url = mockHTTP.lastRequest?.url
        #expect(url?.host == "api.github.com")
        let path = url?.path ?? ""
        #expect(path.hasPrefix("/repos/octocat/hello-world/"))
    }

    // MARK: - syncDependabotAlerts

    /// Verifies that a two-alert response is decoded and persisted with all expected fields.
    @Test func syncDependabotAlertsCreatesAlerts() async throws {
        let json = """
        [
          {
            "number": 42,
            "created_at": "2024-01-15T10:00:00Z",
            "html_url": "https://github.com/apple/swift/security/dependabot/42",
            "security_advisory": {
              "ghsa_id": "GHSA-1234-5678-abcd",
              "cve_id": "CVE-2024-0001",
              "summary": "Prototype pollution in lodash",
              "description": "Lodash versions prior to 4.17.21 are vulnerable to prototype pollution.",
              "severity": "high",
              "cvss": { "score": 7.5 }
            },
            "security_vulnerability": {
              "package": { "ecosystem": "npm", "name": "lodash" },
              "first_patched_version": { "identifier": "4.17.21" },
              "vulnerable_version_range": "< 4.17.21"
            },
            "dependency": { "manifest_path": "package-lock.json" },
            "assignees": [{ "login": "alice" }]
          },
          {
            "number": 99,
            "created_at": "2024-02-20T08:30:00Z",
            "html_url": "https://github.com/apple/swift/security/dependabot/99",
            "security_advisory": {
              "ghsa_id": "GHSA-abcd-1234-5678",
              "cve_id": null,
              "summary": "Server-side request forgery in axios",
              "description": "Axios is vulnerable to SSRF.",
              "severity": "critical",
              "cvss": null
            },
            "security_vulnerability": {
              "package": { "ecosystem": "npm", "name": "axios" },
              "first_patched_version": null,
              "vulnerable_version_range": ">= 0.8.1, < 1.6.0"
            },
            "dependency": { "manifest_path": null },
            "assignees": []
          }
        ]
        """
        mockHTTP.setSuccess(json: json)

        let container = try makeContainer()
        let context = container.mainContext
        let repo = SavedRepository(githubId: "1", owner: "apple", name: "swift", displayName: "swift")
        context.insert(repo)

        await makeService().syncDependabotAlerts(owner: "apple", repo: "swift", repository: repo, in: context)

        let alerts = repo.dependabotAlertDetails.sorted { $0.alertNumber < $1.alertNumber }
        #expect(alerts.count == 2)

        let first = try #require(alerts.first)
        #expect(first.alertNumber == 42)
        #expect(first.packageName == "lodash")
        #expect(first.severity == "high")
        #expect(first.fixVersion == "4.17.21")
        #expect(first.summary == "Prototype pollution in lodash")
        #expect(first.ecosystem == "npm")
        #expect(first.vulnerableVersionRange == "< 4.17.21")
        #expect(first.ghsaId == "GHSA-1234-5678-abcd")
        #expect(first.cveId == "CVE-2024-0001")
        #expect(first.cvssScore == 7.5)
        #expect(first.htmlUrl == "https://github.com/apple/swift/security/dependabot/42")
        #expect(first.manifestPath == "package-lock.json")
        #expect(first.assignedLogins == ["alice"])

        let second = alerts[1]
        #expect(second.alertNumber == 99)
        #expect(second.packageName == "axios")
        #expect(second.severity == "critical")
        #expect(second.fixVersion == nil)
        #expect(second.cveId == nil)
        #expect(second.cvssScore == nil)
        #expect(second.manifestPath == nil)
    }

    /// Verifies that a second sync replaces previously persisted alerts rather than appending.
    @Test func syncDependabotAlertsReplacesExistingAlerts() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let repo = SavedRepository(githubId: "1", owner: "apple", name: "swift", displayName: "swift")
        context.insert(repo)

        // Insert a stale alert and persist it
        let stale = DependabotAlert(alertNumber: 1, packageName: "old-pkg", severity: "low", fixVersion: nil, createdAt: Date())
        stale.repository = repo
        context.insert(stale)
        try context.save()
        #expect(repo.dependabotAlertDetails.count == 1)

        let json = """
        [
          {
            "number": 7,
            "created_at": "2024-03-01T00:00:00Z",
            "html_url": "https://github.com/apple/swift/security/dependabot/7",
            "security_advisory": {
              "ghsa_id": "GHSA-0000-0000-0000",
              "cve_id": null,
              "summary": "Vulnerability in new-pkg",
              "description": "Description of the vulnerability.",
              "severity": "medium",
              "cvss": null
            },
            "security_vulnerability": {
              "package": { "ecosystem": "pip", "name": "new-pkg" },
              "first_patched_version": null,
              "vulnerable_version_range": ">= 1.0, < 2.0"
            },
            "dependency": { "manifest_path": "requirements.txt" },
            "assignees": []
          }
        ]
        """
        mockHTTP.setSuccess(json: json)

        await makeService().syncDependabotAlerts(owner: "apple", repo: "swift", repository: repo, in: context)

        #expect(repo.dependabotAlertDetails.count == 1)
        let alert = try #require(repo.dependabotAlertDetails.first)
        #expect(alert.alertNumber == 7)
        #expect(alert.packageName == "new-pkg")
    }

    /// Verifies that alerts from multiple pages are all persisted when the API returns a `Link: rel="next"` header.
    @Test func syncDependabotAlertsFetchesAllPages() async throws {
        let page1 = """
        [
          {
            "number": 1,
            "created_at": "2024-01-01T00:00:00Z",
            "html_url": "https://github.com/apple/swift/security/dependabot/1",
            "security_advisory": {
              "ghsa_id": "GHSA-0001-0001-0001",
              "cve_id": null,
              "summary": "Page 1 alert",
              "description": "Description.",
              "severity": "low",
              "cvss": null
            },
            "security_vulnerability": {
              "package": { "ecosystem": "npm", "name": "pkg-a" },
              "first_patched_version": null,
              "vulnerable_version_range": ">= 1.0, < 2.0"
            },
            "dependency": { "manifest_path": "package.json" },
            "assignees": []
          }
        ]
        """
        let page2 = """
        [
          {
            "number": 2,
            "created_at": "2024-02-01T00:00:00Z",
            "html_url": "https://github.com/apple/swift/security/dependabot/2",
            "security_advisory": {
              "ghsa_id": "GHSA-0002-0002-0002",
              "cve_id": null,
              "summary": "Page 2 alert",
              "description": "Description.",
              "severity": "high",
              "cvss": null
            },
            "security_vulnerability": {
              "package": { "ecosystem": "pip", "name": "pkg-b" },
              "first_patched_version": null,
              "vulnerable_version_range": ">= 0.1, < 1.0"
            },
            "dependency": { "manifest_path": "requirements.txt" },
            "assignees": []
          }
        ]
        """

        // Page 1 comes with a Link header; page 2 has no Link header (last page)
        mockHTTP.enqueueSuccess(
            json: page1,
            headers: ["Link": "<https://api.github.com/repos/apple/swift/dependabot/alerts?state=open&per_page=100&page=2>; rel=\"next\""]
        )
        mockHTTP.enqueueSuccess(json: page2)

        let container = try makeContainer()
        let context = container.mainContext
        let repo = SavedRepository(githubId: "1", owner: "apple", name: "swift", displayName: "swift")
        context.insert(repo)

        await makeService().syncDependabotAlerts(owner: "apple", repo: "swift", repository: repo, in: context)

        let alerts = repo.dependabotAlertDetails.sorted { $0.alertNumber < $1.alertNumber }
        #expect(alerts.count == 2)
        #expect(alerts[0].alertNumber == 1)
        #expect(alerts[0].packageName == "pkg-a")
        #expect(alerts[1].alertNumber == 2)
        #expect(alerts[1].packageName == "pkg-b")
    }

    /// Verifies that existing alerts are preserved when the network call returns an error.
    @Test func syncDependabotAlertsKeepsExistingOnError() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let repo = SavedRepository(githubId: "1", owner: "apple", name: "swift", displayName: "swift")
        context.insert(repo)

        let existing = DependabotAlert(alertNumber: 5, packageName: "kept-pkg", severity: "low", fixVersion: nil, createdAt: Date())
        existing.repository = repo
        context.insert(existing)

        mockHTTP.setSuccess(json: "{}", statusCode: 403)

        await makeService().syncDependabotAlerts(owner: "apple", repo: "swift", repository: repo, in: context)

        #expect(repo.dependabotAlertDetails.count == 1)
    }

    // MARK: - syncCodeScanningAlerts

    /// Verifies that a two-alert response is decoded and persisted correctly.
    @Test func syncCodeScanningAlertsCreatesAlerts() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let repo = SavedRepository(githubId: "id1", owner: "apple", name: "swift", displayName: "Apple Swift")
        context.insert(repo)

        mockHTTP.setSuccess(json: """
        [
          {
            "number": 42,
            "created_at": "2024-01-15T10:00:00Z",
            "html_url": "https://github.com/apple/swift/security/code-scanning/42",
            "rule": {
              "name": "java/sql-injection",
              "security_severity_level": "high"
            }
          },
          {
            "number": 7,
            "created_at": "2024-02-20T08:30:00Z",
            "html_url": "https://github.com/apple/swift/security/code-scanning/7",
            "rule": {
              "name": "js/xss",
              "security_severity_level": null
            }
          }
        ]
        """)

        await makeService().syncCodeScanningAlerts(owner: "apple", repo: "swift", repository: repo, in: context)

        let alerts = repo.codeScanningAlertDetails.sorted { $0.alertNumber < $1.alertNumber }
        #expect(alerts.count == 2)
        #expect(alerts[0].alertNumber == 7)
        #expect(alerts[0].ruleName == "js/xss")
        #expect(alerts[0].securitySeverityLevel == nil)
        #expect(alerts[1].alertNumber == 42)
        #expect(alerts[1].ruleName == "java/sql-injection")
        #expect(alerts[1].securitySeverityLevel == "high")
    }

    /// Verifies that a second sync replaces all previously persisted alerts.
    @Test func syncCodeScanningAlertsReplacesExistingAlerts() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let repo = SavedRepository(githubId: "id1", owner: "apple", name: "swift", displayName: "Apple Swift")
        context.insert(repo)

        // First sync: two alerts
        mockHTTP.setSuccess(json: """
        [
          {
            "number": 1,
            "created_at": "2024-01-01T00:00:00Z",
            "html_url": "https://github.com/apple/swift/security/code-scanning/1",
            "rule": { "name": "old-rule", "security_severity_level": "low" }
          },
          {
            "number": 2,
            "created_at": "2024-01-02T00:00:00Z",
            "html_url": "https://github.com/apple/swift/security/code-scanning/2",
            "rule": { "name": "another-old-rule", "security_severity_level": "medium" }
          }
        ]
        """)
        await makeService().syncCodeScanningAlerts(owner: "apple", repo: "swift", repository: repo, in: context)
        #expect(repo.codeScanningAlertDetails.count == 2)

        // Second sync: one new alert
        mockHTTP.setSuccess(json: """
        [
          {
            "number": 99,
            "created_at": "2024-03-01T00:00:00Z",
            "html_url": "https://github.com/apple/swift/security/code-scanning/99",
            "rule": { "name": "new-rule", "security_severity_level": "critical" }
          }
        ]
        """)
        await makeService().syncCodeScanningAlerts(owner: "apple", repo: "swift", repository: repo, in: context)

        #expect(repo.codeScanningAlertDetails.count == 1)
        #expect(repo.codeScanningAlertDetails[0].alertNumber == 99)
        #expect(repo.codeScanningAlertDetails[0].ruleName == "new-rule")
    }

    /// Verifies that an empty array response leaves the alert list empty.
    @Test func syncCodeScanningAlertsHandlesEmptyResponse() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let repo = SavedRepository(githubId: "id1", owner: "apple", name: "swift", displayName: "Apple Swift")
        context.insert(repo)

        mockHTTP.setSuccess(json: "[]")
        await makeService().syncCodeScanningAlerts(owner: "apple", repo: "swift", repository: repo, in: context)

        #expect(repo.codeScanningAlertDetails.isEmpty)
    }

    /// Verifies that a 403 response does not crash and leaves alerts unchanged.
    @Test func syncCodeScanningAlertsHandlesError() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let repo = SavedRepository(githubId: "id1", owner: "apple", name: "swift", displayName: "Apple Swift")
        context.insert(repo)

        mockHTTP.setSuccess(json: "{}", statusCode: 403)
        await makeService().syncCodeScanningAlerts(owner: "apple", repo: "swift", repository: repo, in: context)

        // Should not crash and leave alerts unchanged
        #expect(repo.codeScanningAlertDetails.isEmpty)
    }

    /// Verifies that each created alert has its repository relationship set to the source repository.
    @Test func syncCodeScanningAlertsSetsRepository() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let repo = SavedRepository(githubId: "id1", owner: "apple", name: "swift", displayName: "Apple Swift")
        context.insert(repo)

        mockHTTP.setSuccess(json: """
        [
          {
            "number": 5,
            "created_at": "2024-06-01T12:00:00Z",
            "html_url": "https://github.com/apple/swift/security/code-scanning/5",
            "rule": { "name": "some-rule", "security_severity_level": "medium" }
          }
        ]
        """)
        await makeService().syncCodeScanningAlerts(owner: "apple", repo: "swift", repository: repo, in: context)

        let alert = try #require(repo.codeScanningAlertDetails.first)
        #expect(alert.repository === repo)
    }

    // MARK: - syncSecretScanningAlerts

    /// Verifies that a two-alert response is decoded and persisted with all expected fields.
    @Test func syncSecretScanningAlertsCreatesAlerts() async throws {
        let json = """
        [
            {
                "number": 1,
                "secret_type_display_name": "GitHub Personal Access Token",
                "validity": "active",
                "publicly_leaked": false,
                "created_at": "2024-01-15T10:00:00Z"
            },
            {
                "number": 2,
                "secret_type_display_name": "AWS Access Key",
                "validity": "unknown",
                "publicly_leaked": true,
                "created_at": "2024-02-20T12:30:00Z"
            }
        ]
        """
        mockHTTP.setSuccess(json: json)

        let container = try makeContainer()
        let context = ModelContext(container)

        let repo = SavedRepository(githubId: "1", owner: "apple", name: "swift", displayName: "apple/swift")
        context.insert(repo)

        await makeService().syncSecretScanningAlerts(owner: "apple", repo: "swift", repository: repo, in: context)

        let alerts = repo.secretScanningAlertDetails.sorted { $0.alertNumber < $1.alertNumber }
        #expect(alerts.count == 2)

        #expect(alerts[0].alertNumber == 1)
        #expect(alerts[0].secretTypeDisplayName == "GitHub Personal Access Token")
        #expect(alerts[0].validity == "active")
        #expect(alerts[0].publiclyLeaked == false)

        #expect(alerts[1].alertNumber == 2)
        #expect(alerts[1].secretTypeDisplayName == "AWS Access Key")
        #expect(alerts[1].validity == "unknown")
        #expect(alerts[1].publiclyLeaked == true)
    }

    /// Verifies that a second sync replaces the previously persisted stale alert.
    @Test func syncSecretScanningAlertsReplacesExisting() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let repo = SavedRepository(githubId: "1", owner: "apple", name: "swift", displayName: "apple/swift")
        context.insert(repo)

        // Insert a stale alert
        let stale = SecretScanningAlert(
            alertNumber: 99,
            secretTypeDisplayName: "Old Secret",
            validity: "inactive",
            publiclyLeaked: false,
            createdAt: Date()
        )
        stale.repository = repo
        context.insert(stale)

        let json = """
        [
            {
                "number": 1,
                "secret_type_display_name": "GitHub Personal Access Token",
                "validity": "active",
                "publicly_leaked": false,
                "created_at": "2024-01-15T10:00:00Z"
            }
        ]
        """
        mockHTTP.setSuccess(json: json)

        await makeService().syncSecretScanningAlerts(owner: "apple", repo: "swift", repository: repo, in: context)

        let alerts = repo.secretScanningAlertDetails
        #expect(alerts.count == 1)
        #expect(alerts[0].alertNumber == 1)
    }

    /// Verifies that a 403 response leaves the alert list empty.
    @Test func syncSecretScanningAlertsHandlesError() async throws {
        mockHTTP.setSuccess(json: "{}", statusCode: 403)

        let container = try makeContainer()
        let context = ModelContext(container)

        let repo = SavedRepository(githubId: "1", owner: "apple", name: "swift", displayName: "apple/swift")
        context.insert(repo)

        await makeService().syncSecretScanningAlerts(owner: "apple", repo: "swift", repository: repo, in: context)

        #expect(repo.secretScanningAlertDetails.isEmpty)
    }

    /// Verifies that the request targets the secret-scanning endpoint for the given owner and repo.
    @Test func syncSecretScanningAlertsUsesCorrectEndpoint() async throws {
        mockHTTP.setSuccess(json: "[]")

        let container = try makeContainer()
        let context = ModelContext(container)

        let repo = SavedRepository(githubId: "1", owner: "octocat", name: "hello-world", displayName: "octocat/hello-world")
        context.insert(repo)

        await makeService().syncSecretScanningAlerts(owner: "octocat", repo: "hello-world", repository: repo, in: context)

        let url = mockHTTP.lastRequest?.url
        #expect(url?.path == "/repos/octocat/hello-world/secret-scanning/alerts")
    }
}
