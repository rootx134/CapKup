import Foundation

class CloudProject: Identifiable, Codable, ObservableObject {
    var id: String
    var name: String
    var remoteId: String
    var totalSize: Int
    var lastModified: Date
    var thumbnailFileId: String?      // Remote ID of _thumb.jpg on Drive
    var ownerAccountId: String?       // Google user sub that owns this project (nil = legacy single-account)

    init(
        id: String = UUID().uuidString,
        name: String,
        remoteId: String,
        totalSize: Int,
        lastModified: Date,
        thumbnailFileId: String? = nil,
        ownerAccountId: String? = nil
    ) {
        self.id = id
        self.name = name
        self.remoteId = remoteId
        self.totalSize = totalSize
        self.lastModified = lastModified
        self.thumbnailFileId = thumbnailFileId
        self.ownerAccountId = ownerAccountId
    }
}
