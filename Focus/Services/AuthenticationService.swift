import Foundation
import LocalAuthentication
import Observation
import os
import Security

// MARK: - AuthState

/// The current authentication state of the app session.
enum AuthState: Sendable, Equatable {
    /// No keychain item exists; the user has never signed in on this device.
    case unauthenticated
    /// A biometric-protected keychain item exists but has not been unlocked this session.
    case locked
    /// The token is held in memory and ready to use.
    case authenticated
}

// MARK: - AuthenticationService

/// Manages GitHub PAT storage, biometric protection, and session state.
///
/// `AuthenticationService` operates in three states defined by ``AuthState``:
/// - **Unauthenticated**: no keychain item exists
/// - **Locked**: a biometric-protected item exists but has not been unlocked this session
/// - **Authenticated**: the token is held in memory and ready to use
///
/// All keychain operations go through the injected ``KeychainHelper``.
@Observable
@MainActor
final class AuthenticationService {

    // MARK: - Properties

    /// The current authentication state, updated as the user signs in, unlocks, or signs out.
    private(set) var authState: AuthState = .unauthenticated

    /// Whether an async authentication operation is in progress.
    private(set) var isLoading = false

    /// The most recent authentication error, or `nil` if the last operation succeeded.
    private(set) var error: GitHubError?

    /// Whether the service is in the ``AuthState/authenticated`` state.
    var isAuthenticated: Bool { authState == .authenticated }

    /// The keychain helper used for all PAT read, write, and delete operations.
    private let keychain: KeychainHelper

    /// The keychain account name under which the GitHub PAT is stored.
    private let keychainAccount = "github-pat"

    /// Thread-safe in-memory token cache.
    ///
    /// `OSAllocatedUnfairLock` is `Sendable` and copyable, safe to capture in the
    /// nonisolated ``tokenProvider`` closure and to access from background contexts
    /// including `BGProcessingTask`.
    @ObservationIgnored
    private let _token = OSAllocatedUnfairLock<String?>(initialState: nil)

    /// The in-memory cached token, or `nil` if the user is unauthenticated or locked.
    var token: String? { _token.withLock { $0 } }

    /// UserDefaults key that records whether the keychain item was saved with biometric access control.
    ///
    /// We own this flag rather than relying on `errSecInteractionNotAllowed`, which the
    /// iOS Simulator does not return for biometric-protected items (no Secure Enclave).
    private static let protectedFlagKey = "github-pat-protected"

    // MARK: - Init

    /// Creates an `AuthenticationService` and resolves the initial ``AuthState``.
    ///
    /// On init, the service checks for a biometric-protected flag in UserDefaults. If one is
    /// found, state is set to ``AuthState/locked`` without attempting a keychain read. Otherwise
    /// it looks for a legacy unprotected item and migrates it to a protected item if found.
    ///
    /// - Parameter keychain: The keychain helper to use. Defaults to a new `KeychainHelper()`.
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
    ///
    /// Safe to call from any concurrency context including `BGProcessingTask`.
    /// Returns `nil` if biometric auth has not occurred this session — background
    /// sync checks this and skips gracefully.
    nonisolated var tokenProvider: @Sendable () -> String? {
        let tokenLock = _token
        return { tokenLock.withLock { $0 } }
    }

    // MARK: - Biometric Unlock

    /// Evaluates Face ID / Touch ID, then reads the protected keychain item using the
    /// authorized `LAContext` so no second prompt occurs.
    ///
    /// Falls back to passcode via `.deviceOwnerAuthentication`. Updates ``authState``
    /// to ``AuthState/authenticated`` on success. If biometric succeeds but the keychain
    /// item is missing (e.g. a passcode change wiped the item), resets to
    /// ``AuthState/unauthenticated`` so the user can re-enter their token.
    ///
    /// - Throws: Never — errors are captured and stored in ``error``.
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

    /// Validates the token against the GitHub API, saves it to the keychain with biometric
    /// access control, and transitions to ``AuthState/authenticated``.
    ///
    /// On success, the token is cached in memory and a `protectedFlagKey` entry is written
    /// to UserDefaults. On failure, ``error`` is set and ``authState`` remains unchanged.
    ///
    /// - Parameter pat: The GitHub personal access token to validate and save.
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

    /// Deletes the keychain item, clears the in-memory token, and resets to ``AuthState/unauthenticated``.
    func signOut() {
        keychain.delete(for: keychainAccount)
        UserDefaults.standard.removeObject(forKey: Self.protectedFlagKey)
        _token.withLock { $0 = nil }
        authState = .unauthenticated
        error = nil
    }

    // MARK: - Private

    /// Re-saves a legacy unprotected token with biometric and passcode access control.
    ///
    /// Returns `true` if migration succeeded. Returns `false` if the device has no passcode
    /// or if the save fails — in that case the original item is left intact.
    ///
    /// - Parameters:
    ///   - pat: The GitHub personal access token to re-save.
    ///   - keychain: The keychain helper to use for the save operation.
    ///   - account: The keychain account name for the item.
    /// - Returns: `true` if the item was successfully re-saved with access control; `false` otherwise.
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

    /// Validates a PAT by executing a minimal GraphQL viewer query against the GitHub API.
    ///
    /// - Parameter pat: The token to validate.
    /// - Throws: A ``GitHubError`` if the request fails or the token is invalid.
    private func validateToken(_ pat: String) async throws {
        let client = GraphQLClient(tokenProvider: { pat })
        let _: ViewerResponse = try await client.execute(
            query: "query { viewer { login } }",
            responseType: ViewerResponse.self
        )
    }
}

// MARK: - ViewerResponse

/// A minimal GraphQL response used to validate a GitHub personal access token.
private struct ViewerResponse: Decodable, Sendable {

    /// The authenticated GitHub user returned by the viewer query.
    let viewer: Viewer

    /// The authenticated GitHub user fields returned by the viewer query.
    struct Viewer: Decodable, Sendable {

        /// The GitHub login name of the authenticated user.
        let login: String
    }
}
