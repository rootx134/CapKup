import Foundation

// MARK: - DriveAccount Model
// Represents a single linked Google Drive account.
// Each account has its own OAuth tokens stored in Keychain keyed by accountId.
struct DriveAccount: Identifiable, Codable, Equatable {
    var id: String          // Unique identifier (e.g., Google user sub or UUID)
    var email: String
    var displayName: String
    var quotaUsage: Int64   // Bytes used (fetched from Drive API)
    var quotaLimit: Int64   // Total bytes available (fetched from Drive API)
    var folderId: String?   // Cached CapKup folder ID on this account's Drive
    var isActive: Bool      // Whether this account is enabled for pooling

    init(id: String, email: String, displayName: String) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.quotaUsage = 0
        self.quotaLimit = 0
        self.folderId = nil
        self.isActive = true
    }

    // Free space available on this account
    var freeSpace: Int64 {
        guard quotaLimit > 0 else { return 0 }
        return quotaLimit - quotaUsage
    }

    // Usage percentage (0.0 – 1.0)
    var usageRatio: Double {
        guard quotaLimit > 0 else { return 0 }
        return Double(quotaUsage) / Double(quotaLimit)
    }
}
