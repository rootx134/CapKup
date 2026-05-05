import Foundation

// MARK: - Token Storage (Replaced Keychain with UserDefaults)
// Due to macOS Keychain continuously prompting for permission when the app is built locally
// without an Apple Developer certificate (ad-hoc signed), we now store tokens in UserDefaults.

enum KeychainService {
    enum Key: String {
        case accessToken  = "GoogleDriveAccessToken"
        case refreshToken = "GoogleDriveRefreshToken"
        case tokenExpiry  = "GoogleDriveTokenExpiry"
    }

    // MARK: - Save (single key)
    static func save(key: Key, value: String) {
        UserDefaults.standard.set(value, forKey: key.rawValue)
    }

    // MARK: - Read (single key)
    static func read(key: Key) -> String? {
        return UserDefaults.standard.string(forKey: key.rawValue)
    }

    // MARK: - Delete (single key)
    static func delete(key: Key) {
        UserDefaults.standard.removeObject(forKey: key.rawValue)
    }

    // MARK: - Delete All legacy keys (logout single account)
    static func deleteAll() {
        delete(key: .accessToken)
        delete(key: .refreshToken)
        delete(key: .tokenExpiry)
    }

    // MARK: - Convenience numeric values
    static func saveDouble(key: Key, value: Double) {
        UserDefaults.standard.set(value, forKey: key.rawValue)
    }

    static func readDouble(key: Key) -> Double {
        return UserDefaults.standard.double(forKey: key.rawValue)
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Multi-account API (keyed by accountId)
    // ─────────────────────────────────────────────────────────

    static func save(rawKey: String, value: String) {
        UserDefaults.standard.set(value, forKey: rawKey)
    }

    static func read(rawKey: String) -> String? {
        return UserDefaults.standard.string(forKey: rawKey)
    }

    static func deleteRaw(rawKey: String) {
        UserDefaults.standard.removeObject(forKey: rawKey)
    }

    static func accessTokenKey(for id: String) -> String  { "GoogleDriveAccessToken_\(id)" }
    static func refreshTokenKey(for id: String) -> String { "GoogleDriveRefreshToken_\(id)" }
    static func tokenExpiryKey(for id: String) -> String  { "GoogleDriveTokenExpiry_\(id)" }

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
