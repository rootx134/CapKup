import Foundation
import os

/// Cleans up orphaned *.capkup temp files left in /tmp by a previous crash or force-quit.
/// Call once at app startup, before any sync operations begin.
enum OrphanedTempCleaner {
    static func clean() {
        let tmp = FileManager.default.temporaryDirectory
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: tmp,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: .skipsHiddenFiles
        ) else { return }

        var removedCount = 0
        for fileURL in contents {
            let name = fileURL.lastPathComponent
            // Match: <anything>.capkup  OR  ex_<anything>  (legacy pattern)
            if fileURL.pathExtension == "capkup" || name.hasPrefix("ex_") {
                if (try? FileManager.default.removeItem(at: fileURL)) != nil {
                    removedCount += 1
                    Logger.cleanup.debug("Removed stale temp file: \(name)")
                }
            }
        }

        if removedCount > 0 {
            Logger.cleanup.info("Cleaned \(removedCount) orphaned temp file(s) from /tmp.")
        }
    }
}
