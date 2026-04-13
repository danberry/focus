import Foundation
@testable import Focus

// MARK: - MockHTTPClient

/// A test double for `HTTPClient` that returns programmer-supplied results.
///
/// Configure `result` for a single fixed response, or use `enqueueSuccess(json:statusCode:)`
/// to set up a FIFO sequence of responses for multi-call tests.
final class MockHTTPClient: HTTPClient, @unchecked Sendable {

    // MARK: - Properties

    /// The fixed result returned by `execute(_:)` when the queue is empty.
    var result: Result<(Data, HTTPURLResponse), any Error>?

    /// The most recent request passed to `execute(_:)`.
    var lastRequest: URLRequest?

    /// The FIFO queue of results consumed before falling back to `result`.
    private var resultQueue: [Result<(Data, HTTPURLResponse), any Error>] = []

    // MARK: - Execution

    /// Executes the request by returning the next queued result, or `result` if the queue is empty.
    ///
    /// - Parameter request: The request to record and service.
    /// - Returns: The next configured response.
    /// - Throws: The configured error, or a fatal error if neither the queue nor `result` is set.
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

    /// Configures `result` to succeed with the given data and status code.
    ///
    /// - Parameters:
    ///   - data: The raw response body.
    ///   - statusCode: The HTTP status code; defaults to `200`.
    func setSuccess(data: Data, statusCode: Int = 200) {
        let response = HTTPURLResponse(
            url: URL(string: "https://api.github.com")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        result = .success((data, response))
    }

    /// Configures `result` to succeed with the given JSON string and status code.
    ///
    /// - Parameters:
    ///   - json: A UTF-8 JSON string to use as the response body.
    ///   - statusCode: The HTTP status code; defaults to `200`.
    func setSuccess(json: String, statusCode: Int = 200) {
        setSuccess(data: json.data(using: .utf8)!, statusCode: statusCode)
    }

    /// Configures `result` to fail with the given error.
    ///
    /// - Parameter error: The error to throw from `execute(_:)`.
    func setFailure(_ error: any Error) {
        result = .failure(error)
    }

    /// Enqueues a successful response to be returned by the next `execute(_:)` call.
    ///
    /// Queued responses are consumed in FIFO order before falling back to `result`.
    ///
    /// - Parameters:
    ///   - json: A UTF-8 JSON string to use as the response body.
    ///   - statusCode: The HTTP status code; defaults to `200`.
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
