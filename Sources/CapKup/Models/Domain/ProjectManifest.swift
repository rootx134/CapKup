import Foundation

struct ProjectFileEntry: Codable, Identifiable, Equatable {
    var id: String { relativePath }
    let relativePath: String
    let size: Int
    let modifiedDate: Date
    let fingerprint: String? // Optional deep hash for later
    let remoteFileId: String? // ID on Google Drive
    
    // So sánh nhẹ
    func isDifferent(from other: ProjectFileEntry) -> Bool {
        return self.size != other.size || self.modifiedDate != other.modifiedDate
    }
}

struct ProjectManifest: Codable, Identifiable {
    var id: String { localProjectId }
    let localProjectId: String
    let displayName: String
    var syncVersion: Int
    var files: [ProjectFileEntry]
    
    var lastSynced: Date
}
