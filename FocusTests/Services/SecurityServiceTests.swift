import Testing
import Foundation
import SwiftData
@testable import Focus

@Suite("SecurityService Tests")
@MainActor
struct SecurityServiceTests {
    let mockHTTP = MockHTTPClient()

    private func makeService() -> SecurityService {
        let rest = RESTClient(httpClient: mockHTTP, tokenProvider: { "test-token" })
        return SecurityService(rest: rest)
    }

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: SavedRepository.self, configurations: config)
    }

    @Test func fetchMetricsReturnsCorrectCounts() async {
        // MockHTTPClient returns the same response for every call.
        // All three endpoints return an array of 2 items.
        mockHTTP.setSuccess(json: "[{}, {}]")
        let metrics = await makeService().fetchMetrics(owner: "apple", repo: "swift")

        #expect(metrics.dependabotAlerts == 2)
        #expect(metrics.codeScanningAlerts == 2)
        #expect(metrics.secretScanningAlerts == 2)
    }

    @Test func fetchMetricsHandlesForbidden() async {
        mockHTTP.setSuccess(json: "{}", statusCode: 403)
        let metrics = await makeService().fetchMetrics(owner: "apple", repo: "swift")

        #expect(metrics.dependabotAlerts == nil)
        #expect(metrics.codeScanningAlerts == nil)
        #expect(metrics.secretScanningAlerts == nil)
    }

    @Test func fetchMetricsHandlesNotFound() async {
        mockHTTP.setSuccess(json: "{}", statusCode: 404)
        let metrics = await makeService().fetchMetrics(owner: "apple", repo: "swift")

        #expect(metrics.dependabotAlerts == nil)
        #expect(metrics.codeScanningAlerts == nil)
        #expect(metrics.secretScanningAlerts == nil)
    }

    @Test func fetchMetricsUsesCorrectPath() async {
        mockHTTP.setSuccess(json: "[]")
        _ = await makeService().fetchMetrics(owner: "octocat", repo: "hello-world")

        // lastRequest reflects one of the three parallel calls; verify it targets the expected host and prefix
        let url = mockHTTP.lastRequest?.url
        #expect(url?.host == "api.github.com")
        let path = url?.path ?? ""
        #expect(path.hasPrefix("/repos/octocat/hello-world/"))
    }

    // MARK: - syncCodeScanningAlerts

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
            "rule": {
              "name": "java/sql-injection",
              "security_severity_level": "high"
            }
          },
          {
            "number": 7,
            "created_at": "2024-02-20T08:30:00Z",
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
            "rule": { "name": "old-rule", "security_severity_level": "low" }
          },
          {
            "number": 2,
            "created_at": "2024-01-02T00:00:00Z",
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
            "rule": { "name": "new-rule", "security_severity_level": "critical" }
          }
        ]
        """)
        await makeService().syncCodeScanningAlerts(owner: "apple", repo: "swift", repository: repo, in: context)

        #expect(repo.codeScanningAlertDetails.count == 1)
        #expect(repo.codeScanningAlertDetails[0].alertNumber == 99)
        #expect(repo.codeScanningAlertDetails[0].ruleName == "new-rule")
    }

    @Test func syncCodeScanningAlertsHandlesEmptyResponse() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let repo = SavedRepository(githubId: "id1", owner: "apple", name: "swift", displayName: "Apple Swift")
        context.insert(repo)

        mockHTTP.setSuccess(json: "[]")
        await makeService().syncCodeScanningAlerts(owner: "apple", repo: "swift", repository: repo, in: context)

        #expect(repo.codeScanningAlertDetails.isEmpty)
    }

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
            "rule": { "name": "some-rule", "security_severity_level": "medium" }
          }
        ]
        """)
        await makeService().syncCodeScanningAlerts(owner: "apple", repo: "swift", repository: repo, in: context)

        let alert = try #require(repo.codeScanningAlertDetails.first)
        #expect(alert.repository === repo)
    }
}
