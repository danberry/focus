import Foundation
import LocalAuthentication
import Security

// MARK: - KeychainHelper

struct KeychainHelper: Sendable {
    private let service: String

    init(service: String = "com.danberry.Focus.github-token") {
        self.service = service
    }

    // MARK: - CRUD

    func save(_ value: String, for account: String) throws {
        try save(value, for: account, accessControl: nil)
    }

    func save(_ value: String, for account: String, accessControl: SecAccessControl?) throws {
        guard let data = value.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        // Delete existing item first
        SecItemDelete(query as CFDictionary)

        var addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
        ]

        if let accessControl {
            addQuery[kSecAttrAccessControl as String] = accessControl
        }

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    /// Reads the item, presenting biometric/passcode UI if the item requires it.
    /// Pass a pre-evaluated LAContext to avoid re-prompting.
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

    /// Attempts to read the item without presenting any authentication UI.
    /// Returns the token if the item exists and requires no auth (legacy unprotected item).
    /// Returns nil and sets status to errSecInteractionNotAllowed if the item is biometric-protected.
    /// Returns nil and sets status to errSecItemNotFound if no item exists.
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

enum KeychainError: Error, LocalizedError {
    case saveFailed(OSStatus)
    case readFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            "Keychain save failed with status: \(status)"
        case .readFailed(let status):
            "Keychain read failed with status: \(status)"
        }
    }
}
