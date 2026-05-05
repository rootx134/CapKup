import Foundation

struct ZipArchive {
    // File extensions that are already compressed → store only (-0)
    // Everything else (JSON, plist, xml, csv, txt…) → fast compress (-1)
    private static let preCompressedExtensions: Set<String> = [
        "mp4", "mov", "m4v", "avi", "mkv",
        "mp3", "m4a", "aac", "wav", "flac",
        "jpg", "jpeg", "png", "heic", "heif", "gif", "webp",
        "zip", "gz", "bz2", "xz", "7z", "rar",
        "pdf", "epub",
        "capkup"
    ]

    /// Smart two-pass zip:
    ///  • Pass 1: store-only (-0) for already-compressed media/binary files
    ///  • Pass 2: fast DEFLATE (-1) for text/JSON/plist files
    /// This maximises compression on compressible assets while keeping speed
    /// acceptable for large media projects.
    static func zip(sourceDir: URL, destination: URL) async throws {
        // Collect all files and split by type
        var textPatterns: [String] = []   // passed to zip via -i glob
        var mediaPatterns: [String] = []  // passed to zip via -i glob

        let enumerator = FileManager.default.enumerator(
            at: sourceDir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        while let fileURL = enumerator?.nextObject() as? URL {
            let ext = fileURL.pathExtension.lowercased()
            if preCompressedExtensions.contains(ext) {
                mediaPatterns.append("*.\(ext)")
            } else {
                textPatterns.append(fileURL.pathExtension.isEmpty ? "*" : "*.\(ext)")
            }
        }

        // Deduplicate patterns
        let uniqueMedia = Array(Set(mediaPatterns))
        let uniqueText  = Array(Set(textPatterns))

        // --- Pass 1: store media files (no compression, fast) ---
        if !uniqueMedia.isEmpty {
            let args1: [String] = ["-r", "-X", "-0", "-q", destination.path, "."]
                + uniqueMedia.flatMap { ["-i", $0] }
            try await runZip(arguments: args1, sourceDir: sourceDir)
        }

        // --- Pass 2: DEFLATE text/JSON files (fast level -1) ---
        if !uniqueText.isEmpty {
            // If archive already exists (from pass 1) → update it (-u)
            let existsAlready = FileManager.default.fileExists(atPath: destination.path)
            let flag = existsAlready ? "-u" : ""
            var args2: [String] = ["-r", "-X", "-1", "-q"]
            if !flag.isEmpty { args2.append(flag) }
            args2 += [destination.path, "."]
            args2 += uniqueText.flatMap { ["-i", $0] }
            try await runZip(arguments: args2, sourceDir: sourceDir)
        }

        // Fallback: if no patterns were collected (e.g. empty project) → full store
        if uniqueMedia.isEmpty && uniqueText.isEmpty {
            try await runZip(
                arguments: ["-r", "-X", "-0", "-q", destination.path, "."],
                sourceDir: sourceDir
            )
        }
    }

    static func unzip(sourceArchive: URL, destination: URL) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        // -q: quiet  -o: overwrite without prompting
        process.arguments = ["-q", "-o", sourceArchive.path, "-d", destination.path]

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw NSError(
                domain: "ZipArchive",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: "Lỗi giải nén file mây: \(process.terminationStatus)"]
            )
        }
    }

    // MARK: - Private helpers

    private static func runZip(arguments: [String], sourceDir: URL) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = sourceDir
        process.arguments = arguments

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw NSError(
                domain: "ZipArchive",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: "Lỗi tạo file nén: \(process.terminationStatus)"]
            )
        }
    }
}
