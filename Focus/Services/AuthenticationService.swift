import Foundation
import Observation

// MARK: - AuthenticationService

@Observable
@MainActor
final class AuthenticationService {
    private(set) var token: String?
    private(set) var isLoading = false
    private(set) var error: GitHubError?

    var isAuthenticated: Bool { token != nil }

    private let keychain: KeychainHelper
    private let keychainAccount = "github-pat"

    init(keychain: KeychainHelper = KeychainHelper()) {
        self.keychain = keychain
        self.token = keychain.read(for: keychainAccount)
    }

    // MARK: - Token Provider

    nonisolated var tokenProvider: @Sendable () -> String? {
        // Capture token value at call time via a helper
        let keychain = self.keychain
        let account = self.keychainAccount
        return { keychain.read(for: account) }
    }

    // MARK: - Sign In

    func signIn(token pat: String) async {
        isLoading = true
        error = nil

        do {
            try await validateToken(pat)
            try keychain.save(pat, for: keychainAccount)
            token = pat
        } catch let ghError as GitHubError {
            error = ghError
        } catch {
            self.error = .networkError(underlying: error)
        }

        isLoading = false
    }

    // MARK: - Sign Out

    func signOut() {
        keychain.delete(for: keychainAccount)
        token = nil
        error = nil
    }

    // MARK: - Private

    private func validateToken(_ pat: String) async throws {
        let client = GraphQLClient(tokenProvider: { pat })
        let _: ViewerResponse = try await client.execute(
            query: "query { viewer { login } }",
            responseType: ViewerResponse.self
        )
    }
}

// MARK: - ViewerResponse

private struct ViewerResponse: Decodable, Sendable {
    let viewer: Viewer

    struct Viewer: Decodable, Sendable {
        let login: String
    }
}
