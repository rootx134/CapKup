import Foundation
import os

class BookmarkManager {
    static let shared = BookmarkManager()
    private let defaultsKey = "capkup.localfolder.bookmark"
    
    func saveBookmark(for url: URL) throws {
        let bookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        UserDefaults.standard.set(bookmarkData, forKey: defaultsKey)
    }
    
    func restoreBookmark() -> URL? {
        guard let bookmarkData = UserDefaults.standard.data(forKey: defaultsKey) else { return nil }
        var isStale = false
        do {
            let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
            if isStale {
                // Re-save stale bookmark
                try saveBookmark(for: url)
            }
            return url
        } catch {
            Logger.bookmark.error("Failed to restore security-scoped bookmark: \(error.localizedDescription)")
            return nil
        }
    }
}
