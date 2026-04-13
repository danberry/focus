import Foundation

// MARK: - RESTClient

/// A GitHub REST API (v3) client that builds, authenticates, and executes HTTP requests.
///
/// `RESTClient` provides typed request methods for the GitHub REST API. All
/// requests include the required `Accept` and `X-GitHub-Api-Version` headers.
/// Authentication is supplied via a token provider closure; requests are sent
/// unauthenticated when the provider returns `nil`.
///
/// All network calls are delegated to the injected ``HTTPClient``, making the
/// client testable via ``MockHTTPClient``.
///
/// - Note: Only `GET` and `PATCH` are currently implemented. See TODOs for
///   missing HTTP method coverage.
struct RESTClient: Sendable {

    // MARK: - Properties

    /// The underlying HTTP transport used to execute requests.
    private let httpClient: any HTTPClient

    /// The base URL prepended to all request paths.
    ///
    /// Defaults to `https://api.github.com`.
    private let baseURL: URL

    /// A closure that provides the bearer token for request authorization.
    ///
    /// Returns `nil` when no token is available; requests are sent unauthenticated in that case.
    private let tokenProvider: @Sendable () -> String?

    // MARK: - Init

    /// Creates a `RESTClient` with the given transport, base URL, and token provider.
    ///
    /// - Parameters:
    ///   - httpClient: The HTTP transport to use. Defaults to a `URLSession`-backed client.
    ///   - baseURL: The base URL for all requests. Defaults to `https://api.github.com`.
    ///   - tokenProvider: A closure returning the bearer token, or `nil` for unauthenticated requests.
    init(
        httpClient: any HTTPClient = URLSessionHTTPClient(),
        baseURL: URL = URL(string: "https://api.github.com")!,
        tokenProvider: @escaping @Sendable () -> String?
    ) {
        self.httpClient = httpClient
        self.baseURL = baseURL
        self.tokenProvider = tokenProvider
    }

    // MARK: - GET

    /// Fetches a decodable value from the given API path.
    ///
    /// Appends `queryItems` to the URL when provided. Sets `Accept`,
    /// `X-GitHub-Api-Version`, and (when a token is available) `Authorization` headers.
    ///
    /// - Parameters:
    ///   - path: The API path relative to `baseURL` (e.g., `"/repos/owner/repo/issues"`).
    ///   - queryItems: Optional query parameters appended to the URL.
    /// - Returns: The decoded response value of type `T`.
    /// - Throws: ``GitHubError`` on HTTP errors or decoding failure.
    func get<T: Decodable & Sendable>(
        path: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> T {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        if let token = tokenProvider() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, httpResponse) = try await execute(request)
        try mapHTTPErrors(httpResponse)

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw GitHubError.decodingError(underlying: error)
        }
    }

    // MARK: - PATCH

    // TODO: Add POST and DELETE methods — several GitHub REST endpoints (e.g., creating issues,
    // deleting branches) are unreachable without them.

    /// Sends a PATCH request with a JSON-encoded body and returns a decoded response.
    ///
    /// Encodes `body` using the shared ``encoder`` (snake_case keys). Sets `Accept`,
    /// `Content-Type`, `X-GitHub-Api-Version`, and (when a token is available)
    /// `Authorization` headers.
    ///
    /// - Parameters:
    ///   - path: The API path relative to `baseURL`.
    ///   - body: The request body, encoded as JSON.
    /// - Returns: The decoded response value of type `Response`.
    /// - Throws: ``GitHubError`` on encoding failure, HTTP errors, or decoding failure.
    ///
    /// - Note: Encoding failures are currently thrown as ``GitHubError/decodingError(underlying:)``.
    // TODO: Introduce a dedicated `GitHubError.encodingError` case — encoding failures thrown as
    // `decodingError` make error-handling branches in callers misleading.
    func patch<Body: Encodable & Sendable, Response: Decodable & Sendable>(
        path: String,
        body: Body
    ) async throws -> Response {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        if let token = tokenProvider() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            request.httpBody = try encoder.encode(body)
        } catch {
            throw GitHubError.decodingError(underlying: error)
        }

        let (data, httpResponse) = try await execute(request)
        try mapHTTPErrors(httpResponse)

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw GitHubError.decodingError(underlying: error)
        }
    }

    // MARK: - Private

    /// A JSON decoder configured for GitHub API responses.
    ///
    /// Applies the following strategies:
    /// - **Key decoding**: `.convertFromSnakeCase` — maps `snake_case` JSON keys to `camelCase` Swift properties.
    /// - **Date decoding**: `.iso8601` — parses ISO 8601 date strings (e.g., `"2024-01-15T10:30:00Z"`).
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    /// A JSON encoder configured for GitHub API request bodies.
    ///
    /// Applies the following strategy:
    /// - **Key encoding**: `.convertToSnakeCase` — maps `camelCase` Swift properties to `snake_case` JSON keys.
    ///
    /// - Note: No date encoding strategy is configured; `Date` values in request bodies will use
    ///   the default `Double` (seconds since epoch) representation.
    // TODO: Add `.iso8601` date encoding strategy — GitHub expects ISO 8601 strings in write
    // requests, and the current default (seconds-since-epoch Double) will produce malformed payloads
    // for any `Encodable` body that contains a `Date` field.
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()

    /// Executes a URL request via the underlying ``HTTPClient``, wrapping transport errors.
    ///
    /// Re-throws existing ``GitHubError`` values unchanged; wraps all other errors as
    /// ``GitHubError/networkError(underlying:)``.
    ///
    /// - Parameter request: The fully constructed request to execute.
    /// - Returns: The raw response data and HTTP response metadata.
    /// - Throws: ``GitHubError`` — either re-thrown from the transport or wrapped as `.networkError`.
    private func execute(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            return try await httpClient.execute(request)
        } catch let error as GitHubError {
            throw error
        } catch {
            throw GitHubError.networkError(underlying: error)
        }
    }

    /// Maps non-2xx HTTP status codes to typed ``GitHubError`` values.
    ///
    /// | Status | Condition | Error thrown |
    /// |--------|-----------|--------------|
    /// | 200–299 | Any | *(no error)* |
    /// | 401 | Any | ``GitHubError/unauthorized`` |
    /// | 403 | `X-RateLimit-Remaining: 0` | ``GitHubError/rateLimited(resetDate:)`` with date parsed from `X-RateLimit-Reset` |
    /// | 403 | Otherwise | ``GitHubError/forbidden`` |
    /// | 404 | Any | ``GitHubError/notFound`` |
    /// | Other | Any | ``GitHubError/unexpectedStatusCode(_:)`` |
    ///
    /// - Parameter response: The HTTP response whose status code is evaluated.
    /// - Throws: A ``GitHubError`` matching the status code; does nothing for 2xx responses.
    private func mapHTTPErrors(_ response: HTTPURLResponse) throws {
        switch response.statusCode {
        case 200...299:
            return
        case 401:
            throw GitHubError.unauthorized
        case 403:
            let resetDate = response.value(forHTTPHeaderField: "X-RateLimit-Reset")
                .flatMap { TimeInterval($0) }
                .map { Date(timeIntervalSince1970: $0) }
            if response.value(forHTTPHeaderField: "X-RateLimit-Remaining") == "0" {
                throw GitHubError.rateLimited(resetDate: resetDate)
            }
            throw GitHubError.forbidden
        case 404:
            throw GitHubError.notFound
        default:
            throw GitHubError.unexpectedStatusCode(response.statusCode)
        }
    }
}
