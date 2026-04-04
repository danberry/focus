import Foundation

// MARK: - GitHubError

enum GitHubError: Error, Sendable {
    case unauthorized
    case forbidden
    case notFound
    case rateLimited(resetDate: Date?)
    case graphQLErrors([GraphQLErrorDetail])
    case networkError(underlying: any Error)
    case decodingError(underlying: any Error)
    case unexpectedStatusCode(Int)
    case invalidResponse
}

// MARK: - LocalizedError

extension GitHubError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .unauthorized:
            "Authentication failed. Check your personal access token."
        case .forbidden:
            "Access denied. You don't have permission for this resource."
        case .notFound:
            "The requested resource was not found."
        case .rateLimited(let resetDate):
            if let resetDate {
                "Rate limit exceeded. Resets at \(resetDate.formatted())."
            } else {
                "Rate limit exceeded. Please try again later."
            }
        case .graphQLErrors(let errors):
            errors.map(\.message).joined(separator: "; ")
        case .networkError(let underlying):
            "Network error: \(underlying.localizedDescription)"
        case .decodingError(let underlying):
            "Failed to parse response: \(underlying.localizedDescription)"
        case .unexpectedStatusCode(let code):
            "Unexpected HTTP status code: \(code)"
        case .invalidResponse:
            "Received an invalid response from the server."
        }
    }
}

// MARK: - GraphQLErrorDetail

struct GraphQLErrorDetail: Decodable, Sendable {
    let message: String
    let path: [String]?
}
