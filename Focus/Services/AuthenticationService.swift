import Foundation
import LocalAuthentication
import Observation
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

    /// UserDefaults key that records whether the keychain item was saved with
    /// biometric access control. We own this flag rather than relying on
    /// errSecInteractionNotAllowed, which the iOS Simulator does not return for
    /// biometric-protected items (no Secure Enclave).
    private static let protectedFlagKey = "github-pat-protected"

    init(keychain: KeychainHelper = KeychainHelper()) {
        self.keychain = keychain

        if UserDefaults.standard.bool(forKey: Self.protectedFlagKey) {
            // A biometric-protected PAT was previously saved.
            // Skip readSkippingUI — it returns errSecSuccess on the Simulator
            // even for protected items, which would incorrectly trigger migration.
            authState = .locked
        } else {
            // No protected item recorded. Check for a legacy unprotected item.
            let (value, status) = keychain.readSkippingUI(for: "github-pat")
            switch status {
            case errSecSuccess:
                if let pat = value {
                    // Legacy unprotected item found — migrate it to a protected item
                    // and cache in memory so this session continues without interruption.
                    let migrated = Self.migrateToProtectedItem(pat: pat, keychain: keychain, account: "github-pat")
                    if migrated {
                        UserDefaults.standard.set(true, forKey: Self.protectedFlagKey)
                    }
                    _token.withLock { $0 = pat }
                    authState = .authenticated
                } else {
                    authState = .unauthenticated
                }
            default:
                // errSecItemNotFound or any other error — no token saved.
                authState = .unauthenticated
            }
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
            } else {
                // Biometric succeeded but the keychain item is gone (e.g. passcode
                // change wiped kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly items).
                // Reset to unauthenticated so the user can re-enter their token.
                UserDefaults.standard.removeObject(forKey: Self.protectedFlagKey)
                authState = .unauthenticated
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
                .userPresence,
                &cfError
            ) else {
                throw GitHubError.noPasscodeSet
            }

            try keychain.save(pat, for: keychainAccount, accessControl: accessControl)
            UserDefaults.standard.set(true, forKey: Self.protectedFlagKey)
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
        UserDefaults.standard.removeObject(forKey: Self.protectedFlagKey)
        _token.withLock { $0 = nil }
        authState = .unauthenticated
        error = nil
    }

    // MARK: - Private

    /// Re-saves a legacy unprotected token with biometric + passcode access control.
    /// Returns true if the migration succeeded, false if the device has no passcode
    /// or if the save fails (in which case the original item is left intact).
    @discardableResult
    private static func migrateToProtectedItem(pat: String, keychain: KeychainHelper, account: String) -> Bool {
        var cfError: Unmanaged<CFError>?
        guard let accessControl = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
            .userPresence,
            &cfError
        ) else { return false }

        do {
            try keychain.save(pat, for: account, accessControl: accessControl)
            return true
        } catch {
            // Leave the existing legacy item intact — it will be migrated on
            // a future launch once a passcode is set.
            return false
        }
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
