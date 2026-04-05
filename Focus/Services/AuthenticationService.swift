import Foundation
import LocalAuthentication
import Observation
import os
import Security

// MARK: - AuthState

enum AuthState: Sendable, Equatable {
    case unauthenticated  // no keychain item exists
    case locked           // item exists, biometric not yet evaluated this session
    case authenticated    // token is in memory, ready to use
}

// MARK: - AuthenticationService

@Observable
@MainActor
final class AuthenticationService {
    private(set) var authState: AuthState = .unauthenticated
    private(set) var isLoading = false
    private(set) var error: GitHubError?

    var isAuthenticated: Bool { authState == .authenticated }

    private let keychain: KeychainHelper
    private let keychainAccount = "github-pat"

    /// Thread-safe in-memory token cache. OSAllocatedUnfairLock is Sendable and
    /// copyable, safe to capture in the nonisolated tokenProvider closure and to
    /// access from background contexts including BGProcessingTask.
    @ObservationIgnored
    private let _token = OSAllocatedUnfairLock<String?>(initialState: nil)

    var token: String? { _token.withLock { $0 } }

    init(keychain: KeychainHelper = KeychainHelper()) {
        self.keychain = keychain

        let (value, status) = keychain.readSkippingUI(for: "github-pat")
        switch status {
        case errSecSuccess:
            if let pat = value {
                // Legacy unprotected item found — migrate it to a protected item
                // and cache in memory so this session continues without interruption.
                Self.migrateToProtectedItem(pat: pat, keychain: keychain, account: "github-pat")
                _token.withLock { $0 = pat }
                authState = .authenticated
            } else {
                authState = .unauthenticated
            }
        case errSecInteractionNotAllowed:
            // Protected item exists; biometric unlock required this session.
            authState = .locked
        default:
            // errSecItemNotFound or any other error — no token saved.
            authState = .unauthenticated
        }
    }

    // MARK: - Token Provider

    /// Returns a synchronous closure that reads the in-memory cached token.
    /// Safe to call from any concurrency context including BGProcessingTask.
    /// Returns nil if biometric auth has not occurred this session — background
    /// sync checks this and skips gracefully.
    nonisolated var tokenProvider: @Sendable () -> String? {
        let tokenLock = _token
        return { tokenLock.withLock { $0 } }
    }

    // MARK: - Biometric Unlock

    /// Evaluates Face ID / Touch ID (falling back to passcode via .deviceOwnerAuthentication),
    /// then reads the protected keychain item using the authorized LAContext so no
    /// second prompt occurs. Updates authState to .authenticated on success.
    func authenticateAndLoadToken() async {
        guard authState == .locked else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }

        let context = LAContext()
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                context.evaluatePolicy(
                    .deviceOwnerAuthentication,
                    localizedReason: "Unlock Focus to access your GitHub credentials"
                ) { success, evaluationError in
                    if let evaluationError {
                        continuation.resume(throwing: evaluationError)
                    } else {
                        continuation.resume()
                    }
                }
            }

            if let pat = keychain.read(for: keychainAccount, context: context) {
                _token.withLock { $0 = pat }
                authState = .authenticated
            }
        } catch {
            self.error = .authenticationFailed
        }
    }

    // MARK: - Sign In

    func signIn(token pat: String) async {
        isLoading = true
        error = nil

        do {
            try await validateToken(pat)

            var cfError: Unmanaged<CFError>?
            guard let accessControl = SecAccessControlCreateWithFlags(
                nil,
                kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
                [.biometryCurrentSet, .or, .devicePasscode],
                &cfError
            ) else {
                throw GitHubError.noPasscodeSet
            }

            try keychain.save(pat, for: keychainAccount, accessControl: accessControl)
            _token.withLock { $0 = pat }
            authState = .authenticated
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
        _token.withLock { $0 = nil }
        authState = .unauthenticated
        error = nil
    }

    // MARK: - Private

    /// Re-saves a legacy unprotected token with biometric + passcode access control.
    /// If the device has no passcode, the token is left unprotected (save skipped).
    private static func migrateToProtectedItem(pat: String, keychain: KeychainHelper, account: String) {
        var cfError: Unmanaged<CFError>?
        guard let accessControl = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
            [.biometryCurrentSet, .or, .devicePasscode],
            &cfError
        ) else { return }

        try? keychain.save(pat, for: account, accessControl: accessControl)
    }

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
