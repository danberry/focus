import Foundation

// MARK: - RESTClient

struct RESTClient: Sendable {
    private let httpClient: any HTTPClient
    private let baseURL: URL
    private let tokenProvider: @Sendable () -> String?

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

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
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
}
