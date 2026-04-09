import Foundation
@testable import Focus

// MARK: - MockHTTPClient

final class MockHTTPClient: HTTPClient, @unchecked Sendable {
    var result: Result<(Data, HTTPURLResponse), any Error>?
    var lastRequest: URLRequest?
    private var resultQueue: [Result<(Data, HTTPURLResponse), any Error>] = []

    func execute(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        lastRequest = request
        if !resultQueue.isEmpty {
            return try resultQueue.removeFirst().get()
        }
        guard let result else {
            fatalError("MockHTTPClient.result must be set before calling execute")
        }
        return try result.get()
    }

    // MARK: - Helpers

    func setSuccess(data: Data, statusCode: Int = 200) {
        let response = HTTPURLResponse(
            url: URL(string: "https://api.github.com")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        result = .success((data, response))
    }

    func setSuccess(json: String, statusCode: Int = 200) {
        setSuccess(data: json.data(using: .utf8)!, statusCode: statusCode)
    }

    func setFailure(_ error: any Error) {
        result = .failure(error)
    }

    /// Enqueues a response to be returned by the next `execute` call.
    /// Queued responses are consumed in FIFO order before falling back to `result`.
    func enqueueSuccess(json: String, statusCode: Int = 200) {
        let response = HTTPURLResponse(
            url: URL(string: "https://api.github.com")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        resultQueue.append(.success((json.data(using: .utf8)!, response)))
    }
}
