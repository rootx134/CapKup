import Foundation
import Security

// MARK: - Keychain Wrapper for secure token storage
// Tokens are stored in macOS Keychain (encrypted) instead of UserDefaults (plaintext).
// This is mandatory for open-source distribution — UserDefaults is readable by any app.
//
// Multi-account support: tokens are keyed by accountId suffix.
// Single-account (legacy) keys remain unchanged for backward compatibility.

enum KeychainService {
    private static let service = "com.capkup.sync"

    enum Key: String {
        // Legacy single-account keys (backward compatible)
        case accessToken  = "GoogleDriveAccessToken"
        case refreshToken = "GoogleDriveRefreshToken"
        case tokenExpiry  = "GoogleDriveTokenExpiry"
    }

    // MARK: - Save (single key)
    static func save(key: Key, value: String) {
        let data = value.data(using: .utf8)!
        delete(key: key)
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String:   data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    // MARK: - Read (single key)
    static func read(key: Key) -> String? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Delete (single key)
    static func delete(key: Key) {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Delete All legacy keys (logout single account)
    static func deleteAll() {
        delete(key: .accessToken)
        delete(key: .refreshToken)
        delete(key: .tokenExpiry)
    }

    // MARK: - Convenience numeric values
    static func saveDouble(key: Key, value: Double) {
        save(key: key, value: String(value))
    }

    static func readDouble(key: Key) -> Double {
        guard let str = read(key: key) else { return 0 }
        return Double(str) ?? 0
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Multi-account API (keyed by accountId)
    // Keys follow the pattern: "GoogleDriveAccessToken_<accountId>"
    // ─────────────────────────────────────────────────────────

    static func save(rawKey: String, value: String) {
        let data = value.data(using: .utf8)!
        deleteRaw(rawKey: rawKey)
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: rawKey,
            kSecValueData as String:   data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func read(rawKey: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: rawKey,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func deleteRaw(rawKey: String) {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: rawKey,
        ]
        SecItemDelete(query as CFDictionary)
    }

    // Token keys for a specific account ID
    static func accessTokenKey(for id: String) -> String  { "GoogleDriveAccessToken_\(id)" }
    static func refreshTokenKey(for id: String) -> String { "GoogleDriveRefreshToken_\(id)" }
    static func tokenExpiryKey(for id: String) -> String  { "GoogleDriveTokenExpiry_\(id)" }

    // Save/read/delete helpers scoped to an account ID
    static func saveToken(accessToken: String, refreshToken: String?, expiresIn: TimeInterval, for accountId: String) {
        save(rawKey: accessTokenKey(for: accountId), value: accessToken)
        if let rt = refreshToken {
            save(rawKey: refreshTokenKey(for: accountId), value: rt)
        }
        let expiry = Date().timeIntervalSince1970 + expiresIn
        save(rawKey: tokenExpiryKey(for: accountId), value: String(expiry))
    }

    static func deleteTokens(for accountId: String) {
        deleteRaw(rawKey: accessTokenKey(for: accountId))
        deleteRaw(rawKey: refreshTokenKey(for: accountId))
        deleteRaw(rawKey: tokenExpiryKey(for: accountId))
    }
}
