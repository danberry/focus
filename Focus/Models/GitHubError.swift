import Foundation

// MARK: - GitHubError

/// An error originating from the GitHub API or the app's networking and authentication layers.
enum GitHubError: Error, Sendable {

    /// The request was rejected because the personal access token is missing or invalid.
    case unauthorized

    /// The request was rejected because the authenticated user lacks permission for the resource.
    case forbidden

    /// The requested resource does not exist or is not visible to the authenticated user.
    case notFound

    /// The GitHub API rate limit has been exceeded.
    ///
    /// - Parameter resetDate: The date at which the rate limit resets, or `nil` if not provided by the API.
    case rateLimited(resetDate: Date?)

    /// The GraphQL response contained one or more application-level errors.
    ///
    /// - Parameter errors: The structured error details returned in the `errors` array of the GraphQL response.
    case graphQLErrors([GraphQLErrorDetail])

    /// A transport-layer error occurred before a response was received.
    ///
    /// - Parameter underlying: The underlying `URLSession` or system-level error.
    case networkError(underlying: any Error)

    /// The response body could not be decoded into the expected type.
    ///
    /// - Parameter underlying: The `DecodingError` or other parsing failure.
    case decodingError(underlying: any Error)

    /// The server returned an HTTP status code that the app does not handle.
    ///
    /// - Parameter code: The unrecognized HTTP status code.
    case unexpectedStatusCode(Int)

    /// The server returned a response that could not be interpreted as an `HTTPURLResponse`.
    case invalidResponse

    /// Local authentication (Face ID / passcode) failed or was cancelled.
    case authenticationFailed

    /// The device has no passcode set, preventing secure token storage in the Keychain.
    case noPasscodeSet

    /// A repository with the same owner and name is already saved to the watch list.
    case repositoryAlreadySaved

    /// An organization with the same login is already saved to the watch list.
    case organizationAlreadySaved
}

// MARK: - LocalizedError

extension GitHubError: LocalizedError {

    /// A user-facing description of the error.
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
        case .authenticationFailed:
            "Authentication failed. Please unlock Focus to continue."
        case .noPasscodeSet:
            "A device passcode is required to save your token securely. Set a passcode in Settings and try again."
        case .repositoryAlreadySaved:
            "This repository is already saved."
        case .organizationAlreadySaved:
            "This organization is already saved."
        }
    }
}

// MARK: - GraphQLErrorDetail

/// A single error entry from a GitHub GraphQL API `errors` response array.
struct GraphQLErrorDetail: Decodable, Sendable {

    // MARK: - Properties

    /// The human-readable error message returned by the GraphQL API.
    let message: String

    /// The key path within the query where the error occurred, or `nil` if not provided.
    let path: [String]?
}
