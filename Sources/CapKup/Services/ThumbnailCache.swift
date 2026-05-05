import Foundation
import AppKit
import os

// Singleton cache thumbnail cho Cloud Projects
// Lưu tại ~/Library/Caches/CapKupThumbs/<fileId>.jpg
actor ThumbnailCache {
    static let shared = ThumbnailCache()

    private let cacheDir: URL = {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CapKupThumbs")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    // In-memory cache để tránh đọc disk lặp lại
    private var memCache: [String: NSImage] = [:]

    // Trả về NSImage từ cache hoặc tải từ Drive rồi cache lại
    func thumbnail(for project: CloudProject) async -> NSImage? {
        guard let fileId = project.thumbnailFileId else { return nil }

        // 1. Kiểm tra memory cache
        if let cached = memCache[fileId] { return cached }

        // 2. Kiểm tra disk cache
        let diskURL = cacheDir.appendingPathComponent("\(fileId).jpg")
        if FileManager.default.fileExists(atPath: diskURL.path),
           let img = NSImage(contentsOf: diskURL) {
            memCache[fileId] = img
            return img
        }

        // 3. Tải từ Google Drive
        do {
            let data = try await GoogleDriveService.shared.fetchThumbnailData(remoteId: fileId)
            try data.write(to: diskURL)
            if let img = NSImage(data: data) {
                memCache[fileId] = img
                return img
            }
        } catch {
            Logger.thumbnail.error("Lỗi tải thumbnail \(fileId): \(error.localizedDescription)")
        }

        return nil
    }

    // Xóa cache của 1 project (khi upload lại)
    func invalidate(fileId: String) {
        memCache.removeValue(forKey: fileId)
        let diskURL = cacheDir.appendingPathComponent("\(fileId).jpg")
        try? FileManager.default.removeItem(at: diskURL)
    }
}
