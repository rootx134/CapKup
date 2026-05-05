import Foundation
import Observation

// MARK: - History Entry Model
struct SyncHistoryEntry: Identifiable, Codable {
    let id: String
    let projectName: String
    let action: SyncAction
    let result: SyncResult
    let timestamp: Date
    let fileSize: Int?
    let errorMessage: String?
    
    init(projectName: String, action: SyncAction, result: SyncResult, timestamp: Date = Date(), fileSize: Int? = nil, errorMessage: String? = nil) {
        self.id = UUID().uuidString
        self.projectName = projectName
        self.action = action
        self.result = result
        self.timestamp = timestamp
        self.fileSize = fileSize
        self.errorMessage = errorMessage
    }
    
    enum SyncAction: String, Codable {
        case upload = "upload"
        case download = "download"
        case delete = "delete"
    }
    
    enum SyncResult: String, Codable {
        case success = "success"
        case failed = "failed"
    }
}

// MARK: - History Manager (Observable)
@Observable
class SyncHistoryManager {
    static let shared = SyncHistoryManager()
    
    var entries: [SyncHistoryEntry] = []
    
    private let storageKey = "capkup_sync_history"
    private let maxEntries = 200
    
    private init() {
        loadHistory()
    }
    
    func addEntry(_ entry: SyncHistoryEntry) {
        entries.insert(entry, at: 0)
        
        // Trim old entries
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
        
        saveHistory()
    }
    
    func clearHistory() {
        entries.removeAll()
        saveHistory()
    }
    
    // MARK: - Persistence
    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([SyncHistoryEntry].self, from: data) else {
            return
        }
        entries = decoded
    }
    
    private func saveHistory() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
