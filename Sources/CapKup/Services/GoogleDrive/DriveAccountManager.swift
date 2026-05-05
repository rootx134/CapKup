import Foundation
import Observation
import os

// MARK: - DriveAccountManager
// Central manager for all linked Google Drive accounts.
// Responsibilities:
//   - Persist account list (non-sensitive metadata) to UserDefaults
//   - Access tokens remain in Keychain via KeychainService (keyed by accountId)
//   - Fetch & cache quota for all active accounts concurrently
//   - Smart Router: pick account with most free space for new uploads
//   - Aggregate cloud project list across all active accounts

@Observable
class DriveAccountManager {
    static let shared = DriveAccountManager()

    // Persisted account list (metadata only — no tokens)
    private(set) var accounts: [DriveAccount] = []

    // Computed aggregates
    var totalUsage: Int64 { accounts.filter(\.isActive).reduce(0) { $0 + $1.quotaUsage } }
    var totalLimit: Int64 { accounts.filter(\.isActive).reduce(0) { $0 + $1.quotaLimit } }
    var totalFree: Int64  { accounts.filter(\.isActive).reduce(0) { $0 + $1.freeSpace } }

    private let persistenceKey = "DriveAccountList"

    private init() {
        loadFromDisk()
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Persistence
    // ─────────────────────────────────────────────────────────

    private func loadFromDisk() {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey),
              let decoded = try? JSONDecoder().decode([DriveAccount].self, from: data) else {
            return
        }
        accounts = decoded
    }

    private func saveToDisk() {
        if let data = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(data, forKey: persistenceKey)
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Account Management
    // ─────────────────────────────────────────────────────────

    func addAccount(_ account: DriveAccount) {
        // Prevent duplicates
        if !accounts.contains(where: { $0.id == account.id }) {
            accounts.append(account)
            saveToDisk()
        }
    }

    func removeAccount(id: String) {
        accounts.removeAll { $0.id == id }
        // Also wipe tokens from Keychain
        KeychainService.deleteTokens(for: id)
        saveToDisk()
    }

    func toggleActive(id: String) {
        if let idx = accounts.firstIndex(where: { $0.id == id }) {
            accounts[idx].isActive.toggle()
            saveToDisk()
        }
    }

    func updateQuota(for accountId: String, usage: Int64, limit: Int64) {
        if let idx = accounts.firstIndex(where: { $0.id == accountId }) {
            accounts[idx].quotaUsage = usage
            accounts[idx].quotaLimit = limit
            saveToDisk()
        }
    }

    func updateFolderId(_ folderId: String, for accountId: String) {
        if let idx = accounts.firstIndex(where: { $0.id == accountId }) {
            accounts[idx].folderId = folderId
            saveToDisk()
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Smart Router
    // Returns the active account with the most free space.
    // Falls back to first active account if quotas are unknown.
    // ─────────────────────────────────────────────────────────

    func bestAccountForUpload() -> DriveAccount? {
        let active = accounts.filter(\.isActive)
        guard !active.isEmpty else { return nil }

        // If all accounts have unknown quota (0), just return first
        if active.allSatisfy({ $0.quotaLimit == 0 }) {
            return active.first
        }
        return active.max(by: { $0.freeSpace < $1.freeSpace })
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Quota Refresh (concurrent)
    // Fetches quota for all active accounts simultaneously
    // ─────────────────────────────────────────────────────────

    func refreshAllQuotas() async {
        let activeAccounts = accounts.filter(\.isActive)
        await withTaskGroup(of: Void.self) { group in
            for account in activeAccounts {
                group.addTask {
                    do {
                        let quota = try await GoogleDriveService.shared.fetchStorageQuota(for: account.id)
                        await MainActor.run {
                            self.updateQuota(for: account.id, usage: quota.usage, limit: quota.limit)
                        }
                    } catch {
                        Logger.auth.warning("Quota fetch failed for \(account.email): \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Aggregate Cloud Projects (concurrent)
    // Fetches project lists from all active accounts and merges them.
    // ─────────────────────────────────────────────────────────

    func fetchAllCloudProjects() async throws -> [CloudProject] {
        let activeAccounts = accounts.filter(\.isActive)

        // If no multi-accounts, fall through to legacy single-account path
        if activeAccounts.isEmpty {
            return try await GoogleDriveService.shared.fetchCloudProjects()
        }

        var allProjects: [CloudProject] = []
        var firstError: Error? = nil

        await withTaskGroup(of: Result<[CloudProject], Error>.self) { group in
            for account in activeAccounts {
                group.addTask {
                    do {
                        let projects = try await GoogleDriveService.shared.fetchCloudProjects(for: account.id)
                        return .success(projects)
                    } catch {
                        return .failure(error)
                    }
                }
            }
            for await result in group {
                switch result {
                case .success(let projects):
                    allProjects.append(contentsOf: projects)
                case .failure(let error):
                    if firstError == nil { firstError = error }
                }
            }
        }

        // If all accounts failed, surface the error
        if allProjects.isEmpty, let error = firstError {
            throw error
        }

        // Deduplicate by name (keep most recently modified copy)
        var seen: [String: CloudProject] = [:]
        for project in allProjects {
            if let existing = seen[project.name] {
                if project.lastModified > existing.lastModified {
                    seen[project.name] = project
                }
            } else {
                seen[project.name] = project
            }
        }
        return Array(seen.values)
    }
}
