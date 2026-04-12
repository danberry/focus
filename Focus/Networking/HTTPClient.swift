import Foundation

// MARK: - HTTPClient

/// Executes HTTP requests and returns raw response data.
///
/// Conforming types are responsible for transport only. Auth headers,
/// error mapping, and response decoding are the caller's responsibility.
protocol HTTPClient: Sendable {

    /// Executes a URL request and returns the raw response data and HTTP metadata.
    ///
    /// - Parameter request: The fully constructed request to execute.
    /// - Returns: The raw response body and HTTP response metadata.
    /// - Throws: Any transport-layer error encountered during execution.
    func execute(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

// MARK: - URLSessionHTTPClient

/// An `HTTPClient` implementation backed by `URLSession`.
struct URLSessionHTTPClient: HTTPClient {

    // MARK: - Properties

    /// The URL session used to execute HTTP requests.
    private let session: URLSession

    // MARK: - Init

    /// Creates a client using the given URL session.
    ///
    /// - Parameter session: The URL session to use for requests; defaults to `.shared`.
    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Requests

    /// Executes the request and returns the raw response data and HTTP metadata.
    ///
    /// Passes the response through without status-code inspection. Callers are
    /// responsible for checking the HTTP status code and mapping errors.
    ///
    /// - Parameter request: The fully constructed request to execute.
    /// - Returns: The raw response body and HTTP response metadata.
    /// - Throws: ``GitHubError/invalidResponse`` if the response is not an `HTTPURLResponse`.
    ///           Any transport-layer error from `URLSession` is propagated directly.
    // TODO: Map non-2xx HTTP status codes to typed `GitHubError` values here — callers currently handle raw status codes independently, leading to inconsistent error handling across services.
    func execute(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubError.invalidResponse
        }
        return (data, httpResponse)
    }
}
