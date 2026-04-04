import Foundation

// MARK: - GraphQLClient

struct GraphQLClient: Sendable {
    private let httpClient: any HTTPClient
    private let baseURL: URL
    private let tokenProvider: @Sendable () -> String?

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

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private func execute(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            return try await httpClient.execute(request)
        } catch let error as GitHubError {
            throw error
        } catch {
            throw GitHubError.networkError(underlying: error)
        }
    }

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

    private func decodeEnvelope(data: Data) throws -> GraphQLEnvelope {
        do {
            return try JSONDecoder().decode(GraphQLEnvelope.self, from: data)
        } catch {
            throw GitHubError.decodingError(underlying: error)
        }
    }
}

// MARK: - GraphQLEnvelope

private struct GraphQLEnvelope: Decodable {
    let data: [String: Any]?
    let errors: [GraphQLErrorDetail]?

    private enum CodingKeys: String, CodingKey {
        case data, errors
    }

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

private struct AnyCodable: Decodable {
    let value: Any

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
