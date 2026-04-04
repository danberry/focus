import Testing
@testable import Focus

@Suite("SecurityService Tests")
struct SecurityServiceTests {
    let mockHTTP = MockHTTPClient()

    private func makeService() -> SecurityService {
        let rest = RESTClient(httpClient: mockHTTP, tokenProvider: { "test-token" })
        return SecurityService(rest: rest)
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
}
