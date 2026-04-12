import Foundation
import LocalAuthentication
import Security

// MARK: - KeychainHelper

/// Reads and writes GitHub tokens to the iOS Keychain.
///
/// `KeychainHelper` wraps `SecItem` calls for generic-password items, supporting
/// both unprotected storage and biometric access-control policies.
///
/// **Access-control flags:**
/// Callers that need biometric protection should construct a `SecAccessControl`
/// using `SecAccessControlCreateWithFlags`. Common protection classes:
/// - `.biometryAny` — any enrolled biometric (Face ID or Touch ID) or device passcode.
/// - `.biometryCurrentSet` — the *current* enrolled biometrics only; invalidated if the
///   biometric set changes (e.g., a new fingerprint is added).
/// - `.userPresence` — biometric first, falling back to device passcode.
///
/// Pass the resulting `SecAccessControl` to ``save(_:for:accessControl:)`` when storing
/// the item. On read, pass a pre-evaluated `LAContext` to ``read(for:context:)`` to
/// avoid prompting the user twice.
///
/// **Biometric protection policy:**
/// Items stored without an `accessControl` are protected only by the device passcode
/// (accessibility class `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` by default).
/// Items stored *with* an `accessControl` require the specified biometric or passcode
/// interaction before the data is returned by the Keychain.
struct KeychainHelper: Sendable {

    // MARK: - Properties

    /// The Keychain service identifier that scopes all items managed by this helper.
    private let service: String

    // MARK: - Init

    /// Creates a `KeychainHelper` bound to a service identifier.
    ///
    /// - Parameter service: The Keychain `kSecAttrService` value used to namespace items.
    ///   Defaults to the app's token-storage service string.
    init(service: String = "com.danberry.Focus.github-token") {
        self.service = service
    }

    // MARK: - CRUD

    /// Saves a string value to the Keychain without an access-control policy.
    ///
    /// Equivalent to calling ``save(_:for:accessControl:)`` with `accessControl: nil`.
    /// The item is protected by the device passcode only.
    ///
    /// - Parameters:
    ///   - value: The string value to persist.
    ///   - account: The Keychain account key that identifies this item within the service.
    /// - Throws: ``KeychainError/saveFailed(_:)`` if the underlying `SecItem` call fails.
    func save(_ value: String, for account: String) throws {
        try save(value, for: account, accessControl: nil)
    }

    /// Saves a string value to the Keychain, optionally applying a biometric access-control policy.
    ///
    /// Uses an add-then-update strategy: attempts `SecItemAdd` first; if the item already
    /// exists (`errSecDuplicateItem`), falls back to `SecItemUpdate`. This avoids a window
    /// where the existing item is deleted before the new write is confirmed.
    ///
    /// When `accessControl` is non-nil, the `kSecAttrAccessControl` attribute is set on both
    /// the add and the update query so the protection class is applied (or updated) atomically.
    ///
    /// - Parameters:
    ///   - value: The string value to persist.
    ///   - account: The Keychain account key that identifies this item within the service.
    ///   - accessControl: A `SecAccessControl` describing the biometric or passcode policy to
    ///     enforce on reads. Pass `nil` for passcode-only protection (the default).
    /// - Throws: ``KeychainError/saveFailed(_:)`` if either the add or the update call fails
    ///   with a status other than `errSecDuplicateItem`.
    // TODO: Throw instead of silently returning when UTF-8 encoding of `value` fails — a silent
    // no-op here means callers cannot distinguish a successful save from a failed encoding.
    func save(_ value: String, for account: String, accessControl: SecAccessControl?) throws {
        guard let data = value.data(using: .utf8) else { return }

        var addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
        ]

        if let accessControl {
            addQuery[kSecAttrAccessControl as String] = accessControl
        }

        // Try adding first. If the item already exists, update it in place so
        // we never delete the existing item before confirming the write succeeds.
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        if addStatus == errSecSuccess {
            return
        }

        guard addStatus == errSecDuplicateItem else {
            throw KeychainError.saveFailed(addStatus)
        }

        // Item exists — update it in place.
        let lookupQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        var updateFields: [String: Any] = [kSecValueData as String: data]
        if let accessControl {
            updateFields[kSecAttrAccessControl as String] = accessControl
        }

        let updateStatus = SecItemUpdate(lookupQuery as CFDictionary, updateFields as CFDictionary)
        guard updateStatus == errSecSuccess else {
            throw KeychainError.saveFailed(updateStatus)
        }
    }

    /// Reads a Keychain item, presenting biometric or passcode UI if the item requires it.
    ///
    /// Pass a pre-evaluated `LAContext` (via `evaluatePolicy(_:localizedReason:reply:)`) to
    /// avoid prompting the user a second time when authentication was already performed
    /// earlier in the same flow.
    ///
    /// - Parameters:
    ///   - account: The Keychain account key identifying the item to read.
    ///   - context: An already-evaluated `LAContext` to satisfy biometric protection, or `nil`
    ///     to allow the Keychain to present its own authentication UI.
    /// - Returns: The stored string, or `nil` if the item does not exist, authentication
    ///   is cancelled, or the data cannot be decoded as UTF-8.
    func read(for account: String, context: LAContext? = nil) -> String? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        if let context {
            query[kSecUseAuthenticationContext as String] = context
        }

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    /// Attempts to read a Keychain item without presenting any authentication UI.
    ///
    /// Uses `kSecUseAuthenticationUISkip` so the Keychain returns immediately rather than
    /// blocking on a Face ID or passcode prompt. Callers can inspect the returned `status`
    /// to distinguish the three outcomes:
    /// - `errSecSuccess` — item exists and required no auth (unprotected item).
    /// - `errSecInteractionNotAllowed` — item exists but is biometric-protected; call
    ///   ``read(for:context:)`` with a valid `LAContext` to retrieve it.
    /// - `errSecItemNotFound` — no item exists for this account.
    ///
    /// - Parameter account: The Keychain account key identifying the item to read.
    /// - Returns: A tuple of the decoded string (or `nil`) and the raw `OSStatus` from
    ///   `SecItemCopyMatching`.
    func readSkippingUI(for account: String) -> (value: String?, status: OSStatus) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationUI as String: kSecUseAuthenticationUISkip,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let data = result as? Data {
            return (String(data: data, encoding: .utf8), errSecSuccess)
        }
        return (nil, status)
    }

    /// Deletes the Keychain item for the given account.
    ///
    /// Silently succeeds if no item exists for `account`.
    ///
    /// - Parameter account: The Keychain account key identifying the item to remove.
    // TODO: Surface the OSStatus from `SecItemDelete` — callers cannot currently detect
    // whether a delete failed due to a Keychain error vs. the item simply not existing.
    func delete(for account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - KeychainError

/// Errors thrown by ``KeychainHelper`` operations.
enum KeychainError: Error, LocalizedError {

    /// A `SecItemAdd` or `SecItemUpdate` call failed with the given `OSStatus`.
    case saveFailed(OSStatus)

    /// A `SecItemCopyMatching` call failed with the given `OSStatus`.
    ///
    /// - Note: ``KeychainHelper/read(for:context:)`` and
    ///   ``KeychainHelper/readSkippingUI(for:)`` currently return `nil` on failure
    ///   rather than throwing this case. This case is reserved for future use.
    // TODO: Wire `readFailed` into read paths so callers can distinguish a missing item
    // from a Keychain access error — currently both silently return `nil`.
    case readFailed(OSStatus)

    /// A human-readable description of the error suitable for display or logging.
    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            "Keychain save failed with status: \(status)"
        case .readFailed(let status):
            "Keychain read failed with status: \(status)"
        }
    }
}
