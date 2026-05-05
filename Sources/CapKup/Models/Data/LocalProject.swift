import Foundation

class LocalProject: Identifiable, ObservableObject {
    let id: String
    @Published var name: String
    @Published var rootPath: String
    @Published var totalSize: Int
    @Published var lastModified: Date
    @Published var status: SyncStatus
    @Published var lastSyncedDate: Date? = nil
    @Published var isDownloaded: Bool = false
    @Published var downloadedAt: Date? = nil
    
    init(id: String = UUID().uuidString, name: String, rootPath: String, totalSize: Int, lastModified: Date, status: SyncStatus = .notBackedUp) {
        self.id = id
        self.name = name
        self.rootPath = rootPath
        self.totalSize = totalSize
        self.lastModified = lastModified
        self.status = status
    }
}

enum SyncStatus: String, Codable {
    case notBackedUp = "Chưa backup"
    case hasChanges = "Có thay đổi mới"
    case waiting = "Chờ xếp hàng"
    case synced = "Đã backup"
    case failed = "Tải lên thất bại"
}
