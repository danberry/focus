import Foundation

// MARK: - GraphQLClient

/// Executes GraphQL queries against the GitHub GraphQL API.
///
/// `GraphQLClient` handles request construction, authorization header injection,
/// HTTP error mapping, and response envelope decoding. HTTP-level errors are
/// mapped to typed ``GitHubError`` values before the response body is inspected.
/// GraphQL-level errors are surfaced as ``GitHubError/graphQLErrors(_:)``.
///
/// All network calls are dispatched through the injected ``HTTPClient``.
struct GraphQLClient: Sendable {

    // MARK: - Properties

    /// The HTTP client used to execute the underlying network request.
    private let httpClient: any HTTPClient

    /// The endpoint URL for the GitHub GraphQL API.
    private let baseURL: URL

    /// A closure that returns the current OAuth token, or `nil` if the user is not authenticated.
    private let tokenProvider: @Sendable () -> String?

    // MARK: - Init

    /// Creates a `GraphQLClient` wired to an HTTP client and token provider.
    ///
    /// - Parameters:
    ///   - httpClient: The transport used to send requests. Defaults to `URLSessionHTTPClient`.
    ///   - baseURL: The GraphQL endpoint. Defaults to the GitHub GraphQL API.
    ///   - tokenProvider: A closure returning the current auth token, or `nil` if unauthenticated.
    init(
        httpClient: any HTTPClient = URLSessionHTTPClient(),
        baseURL: URL = URL(string: "https://api.github.com/graphql")!,
        tokenProvider: @escaping @Sendable () -> String?
    ) {
        self.httpClient = httpClient
        self.baseURL = baseURL
        self.tokenProvider = tokenProvider
    }

    // MARK: - Query Execution

    /// Executes a GraphQL query and decodes the response into the specified type.
    ///
    /// Builds a POST request containing the query and optional variables, dispatches it
    /// through ``HTTPClient``, maps HTTP errors, unwraps the GraphQL envelope, and decodes
    /// the `data` field into `T`.
    ///
    /// When the response contains both `data` and `errors`, the errors are silently discarded
    /// and decoding proceeds on `data`.
    ///
    /// // TODO: Surface partial-success errors alongside decoded data — currently errors are
    /// // discarded when `data` is non-nil, which can hide field-level permission or
    /// // validation failures from callers.
    ///
    /// - Parameters:
    ///   - query: The GraphQL query string.
    ///   - variables: Key-value pairs substituted into the query. Defaults to `nil`.
    ///   - responseType: The `Decodable` type to decode from the `data` envelope field.
    /// - Returns: A decoded value of `responseType`.
    /// - Throws: ``GitHubError`` for HTTP errors, GraphQL errors, decoding failures, or
    ///   transport-layer errors.
    func execute<T: Decodable & Sendable>(
        query: String,
        variables: [String: any Sendable]? = nil,
        responseType: T.Type
    ) async throws -> T {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = tokenProvider() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // TODO: Replace JSONSerialization variable encoding with a Codable-based approach —
        // JSONSerialization silently drops non-JSON-compatible Sendable values rather than
        // throwing, making variable encoding failures hard to diagnose at the call site.
        var body: [String: Any] = ["query": query]
        if let variables {
            body["variables"] = variables
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, httpResponse) = try await execute(request)
        try mapHTTPErrors(httpResponse)

        let envelope = try decodeEnvelope(data: data)

        if let errors = envelope.errors, !errors.isEmpty {
            if envelope.data == nil {
                throw GitHubError.graphQLErrors(errors)
            }
        }

        guard let responseData = envelope.data else {
            throw GitHubError.invalidResponse
        }

        let jsonData = try JSONSerialization.data(withJSONObject: responseData)
        return try decoder.decode(T.self, from: jsonData)
    }

    // MARK: - Private

    /// A JSON decoder configured for GitHub API responses.
    ///
    /// Applies snake_case-to-camelCase key conversion and ISO 8601 date decoding.
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    /// Executes a URL request, wrapping non-``GitHubError`` transport failures in
    /// ``GitHubError/networkError(underlying:)``.
    ///
    /// - Parameter request: The fully constructed URL request to send.
    /// - Returns: The raw response body and HTTP metadata.
    /// - Throws: ``GitHubError/networkError(underlying:)`` for transport-layer errors, or a
    ///   passthrough ``GitHubError`` if the underlying client already throws one.
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
    /// - 2xx → success (no error thrown)
    /// - 401 → ``GitHubError/unauthorized``
    /// - 403 with exhausted rate limit → ``GitHubError/rateLimited(resetDate:)``
    /// - 403 otherwise → ``GitHubError/forbidden``
    /// - 404 → ``GitHubError/notFound``
    /// - Any other non-2xx → ``GitHubError/unexpectedStatusCode(_:)``
    ///
    /// - Parameter response: The HTTP response to inspect.
    /// - Throws: A ``GitHubError`` matching the response status code.
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

    /// Decodes the raw response body into a ``GraphQLEnvelope``, wrapping any failure in
    /// ``GitHubError/decodingError(underlying:)``.
    ///
    /// // TODO: Use the shared `decoder` instead of a fresh `JSONDecoder` — inconsistent
    /// // decoder instances are a latent source of key-mismatch bugs if the envelope
    /// // schema gains snake_case fields in the future.
    ///
    /// - Parameter data: The raw HTTP response body.
    /// - Returns: A decoded ``GraphQLEnvelope``.
    /// - Throws: ``GitHubError/decodingError(underlying:)`` if the data cannot be decoded.
    private func decodeEnvelope(data: Data) throws -> GraphQLEnvelope {
        do {
            return try JSONDecoder().decode(GraphQLEnvelope.self, from: data)
        } catch {
            throw GitHubError.decodingError(underlying: error)
        }
    }
}

// MARK: - GraphQLEnvelope

/// The top-level wrapper for a GitHub GraphQL API response.
///
/// A response may contain `data`, `errors`, or both, matching the GraphQL
/// partial-success specification.
private struct GraphQLEnvelope: Decodable {

    /// The `data` field of the GraphQL response, decoded as a raw dictionary for
    /// downstream re-encoding into a concrete type.
    let data: [String: Any]?

    /// The `errors` array from the GraphQL response, or `nil` if no errors were returned.
    let errors: [GraphQLErrorDetail]?

    /// The coding keys for the GraphQL envelope's top-level fields.
    private enum CodingKeys: String, CodingKey {
        case data, errors
    }

    /// Creates a `GraphQLEnvelope` by decoding the top-level `data` and `errors` fields.
    ///
    /// The `data` field is decoded via ``AnyCodable`` to preserve its arbitrary structure
    /// as a `[String: Any]` dictionary for later re-encoding.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        errors = try container.decodeIfPresent([GraphQLErrorDetail].self, forKey: .errors)

        if let rawData = try? container.decode(AnyCodable.self, forKey: .data) {
            data = rawData.value as? [String: Any]
        } else {
            data = nil
        }
    }
}

// MARK: - AnyCodable

/// A type-erased `Decodable` wrapper that preserves arbitrary JSON values as native Swift types.
///
/// Used to decode the `data` field of a ``GraphQLEnvelope``, which has a schema defined
/// by the query rather than a fixed structure.
///
/// // TODO: Add `Encodable` conformance — the current decode-only implementation prevents
/// // round-tripping GraphQL variables through the same type, forcing `JSONSerialization`
/// // for the request body instead of a unified Codable path.
private struct AnyCodable: Decodable {

    /// The decoded JSON value as a native Swift type (`Bool`, `Int`, `Double`, `String`,
    /// `[Any]`, `[String: Any]`, or `NSNull`).
    let value: Any

    /// Decodes a single JSON value into its native Swift equivalent.
    ///
    /// - Throws: `DecodingError.dataCorrupted` if the container holds a type that cannot
    ///   be represented as a supported Swift primitive.
    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map(\.value)
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues(\.value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type")
        }
    }
}
