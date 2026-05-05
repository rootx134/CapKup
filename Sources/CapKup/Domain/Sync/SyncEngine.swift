import Foundation
import os
import Observation
import AppKit

// MARK: - Sync Phase Enum
enum SyncPhase: Int, Comparable, CaseIterable {
    case idle = 0
    case preparing = 1
    case compressing = 2
    case uploading = 3
    case verifying = 4
    // Download-specific phases
    case downloading = 5
    case decrypting = 6
    case extracting = 7
    
    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
    
    var label: String {
        switch self {
        case .idle: return "Chờ"
        case .preparing: return "Chuẩn bị"
        case .compressing: return "Nén & Mã hoá"
        case .uploading: return "Tải lên"
        case .verifying: return "Xác minh"
        case .downloading: return "Tải về"
        case .decrypting: return "Giải mã"
        case .extracting: return "Giải nén"
        }
    }
    
    var iconName: String {
        switch self {
        case .idle: return "circle"
        case .preparing: return "folder.badge.gearshape"
        case .compressing: return "archivebox"
        case .uploading: return "arrow.up.circle"
        case .verifying: return "checkmark.shield"
        case .downloading: return "arrow.down.circle"
        case .decrypting: return "lock.open"
        case .extracting: return "doc.zipper"
        }
    }
    
    /// Upload flow phases in order
    static var uploadPhases: [SyncPhase] { [.preparing, .compressing, .uploading, .verifying] }
    /// Download flow phases in order
    static var downloadPhases: [SyncPhase] { [.downloading, .decrypting, .extracting] }
}

// MARK: - Speed Sample for sparkline chart
struct SpeedSample: Identifiable {
    let id = UUID()
    let timestamp: Date
    let bytesPerSec: Double
    
    var mbps: Double { bytesPerSec / (1024 * 1024) }
}

@Observable
class SyncEngine {
    static let shared = SyncEngine()
    
    var isSyncing: Bool = false
    var currentProgress: Double = 0.0
    var currentFile: String = ""
    var uploadQueue: [LocalProject] = []
    var downloadQueue: [CloudProject] = []
    var deleteQueue: [CloudProject] = []
    
    var activeUploadProject: LocalProject? = nil
    var activeDownloadProject: CloudProject? = nil
    var activeDeleteProject: CloudProject? = nil
    
    // Phase tracking
    var currentPhase: SyncPhase = .idle
    
    // Speed & ETA tracking
    var transferSpeed: Double = 0           // bytes/sec (current)
    var estimatedTimeRemaining: TimeInterval? = nil
    var speedHistory: [SpeedSample] = []    // rolling 60 samples for sparkline
    
    // Pause / Resume / Cancel
    var isPaused: Bool = false
    var isCancelled: Bool = false
    var activeUploadSessionURL: URL? = nil  // Google Drive resumable session URI
    var activeUploadOffset: Int = 0
    var activeUploadFileSize: Int = 0
    
    // Completion state for inspector
    var lastCompletedName: String? = nil
    var lastCompletedAction: String? = nil
    var lastCompletedSuccess: Bool = true
    var lastCompletedTime: Date? = nil
    
    // Toast trigger
    var showToast: Bool = false
    
    var localRootURL: URL? = nil
    
    // MARK: - Pause / Resume / Cancel Controls
    
    @MainActor
    func pauseSync() {
        guard isSyncing, !isPaused else { return }
        isPaused = true
        Logger.sync.info("Sync paused by user")
    }
    
    @MainActor
    func resumeSync() {
        guard isPaused else { return }
        isPaused = false
        Logger.sync.info("Sync resumed by user")
    }
    
    @MainActor
    func cancelSync() {
        isCancelled = true
        isPaused = false
        Logger.sync.info("Sync cancelled by user")
    }
    
    /// Record a speed sample and compute ETA
    @MainActor
    func recordSpeed(bytesPerSec: Double, totalBytes: Double, bytesTransferred: Double) {
        self.transferSpeed = bytesPerSec
        
        // Rolling 60-sample window
        let sample = SpeedSample(timestamp: Date(), bytesPerSec: bytesPerSec)
        speedHistory.append(sample)
        if speedHistory.count > 60 {
            speedHistory.removeFirst(speedHistory.count - 60)
        }
        
        // Calculate ETA based on average of last 10 samples
        let recentSamples = speedHistory.suffix(10)
        let avgSpeed = recentSamples.map(\.bytesPerSec).reduce(0, +) / Double(recentSamples.count)
        if avgSpeed > 0 {
            let remaining = totalBytes - bytesTransferred
            estimatedTimeRemaining = remaining / avgSpeed
        } else {
            estimatedTimeRemaining = nil
        }
    }
    
    /// Reset all progress state for a new sync task
    @MainActor
    func resetProgressState() {
        currentProgress = 0.0
        currentFile = ""
        currentPhase = .idle
        transferSpeed = 0
        estimatedTimeRemaining = nil
        speedHistory = []
        isPaused = false
        isCancelled = false
        activeUploadSessionURL = nil
        activeUploadOffset = 0
        activeUploadFileSize = 0
    }
    
    /// Mark sync completion and trigger toast + notification
    @MainActor
    func markCompletion(name: String, action: String, success: Bool) {
        self.lastCompletedName = name
        self.lastCompletedAction = action
        self.lastCompletedSuccess = success
        self.lastCompletedTime = Date()
        self.currentPhase = .idle
        self.showToast = true
        
        // Play sound
        NSSound(named: success ? "Glass" : "Basso")?.play()
        
        // System notification (will only fire when app is not active)
        NotificationService.shared.sendCompletionNotification(
            projectName: name,
            action: action,
            success: success
        )
    }
    
    func enqueueProjects(_ projects: [LocalProject]) {
        for project in projects {
            project.status = .waiting
            self.uploadQueue.append(project)
        }
        
        if !isSyncing {
            Task { await processQueue() }
        }
    }
    
    func dequeueProject(_ project: LocalProject) {
        if let index = uploadQueue.firstIndex(where: { $0.id == project.id }) {
            uploadQueue.remove(at: index)
            project.status = .notBackedUp
        }
    }
    
    @MainActor private func getNextUpload() -> LocalProject? {
        if uploadQueue.isEmpty { return nil }
        return uploadQueue.removeFirst()
    }
    
    private func processQueue() async {
        var existingProjects: [CloudProject] = []
        if let list = try? await GoogleDriveService.shared.fetchCloudProjects() {
            existingProjects = list
        }
        
        while let nextProject = await getNextUpload() {
            await MainActor.run { self.activeUploadProject = nextProject }
            
            // Nếu người dùng lỡ tay hủy khi dự án vừa được lôi ra
            if nextProject.status != .waiting { 
                await MainActor.run { self.activeUploadProject = nil }
                continue 
            }
            
            // Lọc tên để tránh "(CapKup)" sinh ra khi download
            let cleanName = nextProject.name.replacingOccurrences(of: " (CapKup)", with: "")
            
            // Nếu trên mây đã có bản cũ mang tên này -> Cập nhật (Xoá bản cũ, up bản mới)
            if let existing = existingProjects.first(where: { $0.name == cleanName }) {
                self.currentFile = "Đang dọn dẹp bản sao cũ..."
                try? await GoogleDriveService.shared.deleteProject(remoteId: existing.remoteId)
                existingProjects.removeAll(where: { $0.id == existing.id })
            }
            
            var uploadName = cleanName
            var names = Set(existingProjects.map { $0.name })
            if names.contains(uploadName) {
                var counter = 1
                let baseName = uploadName
                while names.contains(uploadName) {
                    uploadName = "\(baseName) (\(counter))"
                    counter += 1
                }
                names.insert(uploadName)
                
                // Add back to our tracked array just in case
                existingProjects.append(CloudProject(id: UUID().uuidString, name: uploadName, remoteId: "", totalSize: 0, lastModified: Date()))
            }
            
            do {
                try await syncProject(localProject: nextProject, overrideName: uploadName, remoteManifest: nil)
                
                let now = Date()
                let dateStr = ISO8601DateFormatter().string(from: now)
                let rootURL = URL(fileURLWithPath: nextProject.rootPath)
                try? dateStr.write(to: rootURL.appendingPathComponent(".capkup_sync_meta"), atomically: true, encoding: .utf8)
                
                await MainActor.run { 
                    nextProject.status = .synced 
                    nextProject.lastSyncedDate = now
                    
                    // Record history
                    SyncHistoryManager.shared.addEntry(SyncHistoryEntry(
                        projectName: nextProject.name,
                        action: .upload,
                        result: .success,
                        fileSize: nextProject.totalSize
                    ))
                    
                    // Completion state + toast + notification
                    self.markCompletion(name: nextProject.name, action: "upload", success: true)
                }
                
                // KIỂM TRA LỆNH XÓA BẢN ĐỊA SAU KHI UPLOAD
                if UserDefaults.standard.bool(forKey: "autoDeleteAfterUpload") {
                    do {
                        try FileManager.default.removeItem(at: rootURL)
                        // Báo cho UI gỡ hẳn project này khỏi mảng
                        await MainActor.run {
                            NotificationCenter.default.post(name: Notification.Name("ProjectDidAutoDeleteLocal"), object: nextProject.id)
                        }
                    } catch {
                        Logger.sync.error("Không thể tự động xóa bản địa: \(error.localizedDescription)")
                    }
                }
                
            } catch {
                await MainActor.run { 
                    nextProject.status = .failed
                    
                    // Record history
                    SyncHistoryManager.shared.addEntry(SyncHistoryEntry(
                        projectName: nextProject.name,
                        action: .upload,
                        result: .failed,
                        fileSize: nextProject.totalSize,
                        errorMessage: error.localizedDescription
                    ))
                    
                    // Completion state + toast + notification
                    self.markCompletion(name: nextProject.name, action: "upload", success: false)
                }
                let errorDesc = error.localizedDescription
                let fullErr = String(describing: error)
                let errorText = "[\(Date().description)] LỖI SYNC '\(nextProject.name)':\nPath: \(nextProject.rootPath)\nError: \(errorDesc)\nDetails: \(fullErr)\n----------------------------------------\n"
                let logURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop/CapKupSync_ErrorLog.txt")
                if let data = errorText.data(using: .utf8) {
                    if let handle = try? FileHandle(forWritingTo: logURL) {
                        handle.seekToEndOfFile()
                        handle.write(data)
                        handle.closeFile()
                    } else {
                        try? data.write(to: logURL)
                    }
                }
            }
            
            // Clear active khi xong
            await MainActor.run { 
                self.activeUploadProject = nil 
                NotificationCenter.default.post(name: Notification.Name("CloudRefreshRequested"), object: nil)
                NotificationCenter.default.post(name: Notification.Name("LocalRefreshRequested"), object: nil)
            }
        }
    }
    
    func syncProject(localProject: LocalProject, overrideName: String? = nil, remoteManifest: ProjectManifest?) async throws {
        let finalName = overrideName ?? localProject.name
        let originalURL = URL(fileURLWithPath: localProject.rootPath) // Thư mục gốc KHÔNG ĐƯỢC CHẠM
        
        self.isSyncing = true
        await MainActor.run { self.resetProgressState() }
        defer { self.isSyncing = false }

        // ─────────────────────────────────────────────────────────────────────
        // BƯỚC 0: Upload thumbnail (draft_cover.jpg) lên Drive (không ảnh hưởng luồng chính)
        // ─────────────────────────────────────────────────────────────────────
        await MainActor.run { self.currentPhase = .preparing }
        let coverURL = originalURL.appendingPathComponent("draft_cover.jpg")
        if FileManager.default.fileExists(atPath: coverURL.path) {
            self.currentFile = "Đang upload thumbnail..."
            try? await GoogleDriveService.shared.uploadThumbnail(localURL: coverURL, projectName: finalName)
        }

        // Check cancel
        if await MainActor.run(body: { self.isCancelled }) { throw CancellationError() }

        // ─────────────────────────────────────────────────────────────────────
        // BƯỚC 1: Đọc external media từ PROJECT GỐC (chỉ đọc, không ghi)
        // ─────────────────────────────────────────────────────────────────────
        self.currentFile = "Bòn rút Media Links..."
        var externalMediaPaths: Set<String> = []

        let possibleJSONs = ["draft_content.json", "draft_meta_info.json", "draft_info.json"]
        
        for jsonName in possibleJSONs {
            let draftJsonURL = originalURL.appendingPathComponent(jsonName)
            if FileManager.default.fileExists(atPath: draftJsonURL.path) {
                externalMediaPaths.formUnion(
                    CapCutProjectParser.extractExternalMedia(from: draftJsonURL, projectRootURL: originalURL)
                )
            }
        }
        
        // ─────────────────────────────────────────────────────────────────────
        // BƯỚC 2: Tạo thư mục STAGING tạm — project gốc KHÔNG BỊ THAY ĐỔI
        // ─────────────────────────────────────────────────────────────────────
        let tmp = FileManager.default.temporaryDirectory
        let stagingURL = tmp.appendingPathComponent("capkup_staging_\(UUID().uuidString)")
        defer {
            // Xóa toàn bộ staging khi thoát scope (dù thành công hay lỗi)
            try? FileManager.default.removeItem(at: stagingURL)
        }
        
        self.currentFile = "Chuẩn bị vùng staging..."
        
        // Copy TOÀN BỘ nội dung thư mục gốc vào staging (shallow copy: chỉ file nội bộ)
        try FileManager.default.copyItem(at: originalURL, to: stagingURL)
        
        // Check cancel
        if await MainActor.run(body: { self.isCancelled }) { throw CancellationError() }

        // ─────────────────────────────────────────────────────────────────────
        // BƯỚC 3: Trong STAGING → tạo CapKup_Media_Attachments + symlink media
        //         Rewrite JSON chỉ trong staging — KHÔNG CHẠM file gốc
        // ─────────────────────────────────────────────────────────────────────
        var rewrittenMediaNames = [String]()
        
        if !externalMediaPaths.isEmpty {
            let mediaSubfolderURL = stagingURL.appendingPathComponent("CapKup_Media_Attachments")
            try FileManager.default.createDirectory(at: mediaSubfolderURL, withIntermediateDirectories: true)
            
            self.currentFile = "Hợp nhất \(externalMediaPaths.count) File Media..."
            for mediaPath in externalMediaPaths {
                let mediaUrl = URL(fileURLWithPath: mediaPath)
                var destUrl = mediaSubfolderURL.appendingPathComponent(mediaUrl.lastPathComponent)
                
                var counter = 1
                while FileManager.default.fileExists(atPath: destUrl.path) {
                    let base = mediaUrl.deletingPathExtension().lastPathComponent
                    let ext  = mediaUrl.pathExtension
                    destUrl = mediaSubfolderURL.appendingPathComponent("\(base)_\(counter).\(ext)")
                    counter += 1
                }
                
                // Symlink trỏ về file gốc ngoài máy — zip sẽ follow symlink khi nén
                try? FileManager.default.createSymbolicLink(at: destUrl, withDestinationURL: mediaUrl)
                rewrittenMediaNames.append(destUrl.lastPathComponent)
            }
            
            // Rewrite JSON chỉ trong staging (KHÔNG phải file gốc)
            self.currentFile = "Đồng bộ liên kết staging..."
            for jsonName in possibleJSONs {
                let stagingJsonURL = stagingURL.appendingPathComponent(jsonName)
                guard FileManager.default.fileExists(atPath: stagingJsonURL.path),
                      let stringData = try? String(contentsOf: stagingJsonURL, encoding: .utf8) else { continue }
                
                var patchedString = stringData
                for mediaName in rewrittenMediaNames {
                    let newAbsPath = mediaSubfolderURL.appendingPathComponent(mediaName).path(percentEncoded: false)
                    let rawName = URL(fileURLWithPath: newAbsPath).deletingPathExtension().lastPathComponent
                    let originalName = String(rawName.split(separator: "_").first ?? Substring(rawName))
                        + "." + (newAbsPath.components(separatedBy: ".").last ?? "")
                    let searchName = rewrittenMediaNames.contains(originalName) ? originalName : mediaName
                    
                    let pattern = "\"[^\"]*?/" + NSRegularExpression.escapedPattern(for: searchName) + "\""
                    if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                        patchedString = regex.stringByReplacingMatches(
                            in: patchedString,
                            range: NSRange(patchedString.startIndex..., in: patchedString),
                            withTemplate: "\"\(newAbsPath)\""
                        )
                    }
                    let filePattern = "\"file://[^\"]*?/" + NSRegularExpression.escapedPattern(for: searchName) + "\""
                    if let regex2 = try? NSRegularExpression(pattern: filePattern, options: .caseInsensitive) {
                        patchedString = regex2.stringByReplacingMatches(
                            in: patchedString,
                            range: NSRange(patchedString.startIndex..., in: patchedString),
                            withTemplate: "\"file://\(newAbsPath)\""
                        )
                    }
                }
                // Ghi vào staging JSON (file gốc KHÔNG bị chạm)
                try? patchedString.write(to: stagingJsonURL, atomically: true, encoding: .utf8)
            }
        }
        
        // ─────────────────────────────────────────────────────────────────────
        // BƯỚC 4: Nén & Mã hoá trực tiếp (Streaming Pipeline) → file .capkup
        // Lợi ích: Loại bỏ hoàn toàn tempPlainZip khổng lồ (Giảm 50% dung lượng đĩa)
        // ─────────────────────────────────────────────────────────────────────
        await MainActor.run { self.currentPhase = .compressing }
        let tempZipURL = tmp.appendingPathComponent("\(finalName).capkup")
        try? FileManager.default.removeItem(at: tempZipURL)
        defer { try? FileManager.default.removeItem(at: tempZipURL) }
        
        self.currentFile = "Đang nén & mã hoá tĩnh (Streaming)..."
        try CapKupCrypto.encryptFromDirectory(sourceDir: stagingURL, outputCapkupURL: tempZipURL)
        
        // Check cancel
        if await MainActor.run(body: { self.isCancelled }) { throw CancellationError() }

        // ─────────────────────────────────────────────────────────────────────
        // BƯỚC 5: Tải lên Drive
        // ─────────────────────────────────────────────────────────────────────
        await MainActor.run { self.currentPhase = .uploading }
        self.currentProgress = 0.5
        self.currentFile = "Đang đẩy từng khối dữ liệu lên Drive..."

        let startUploadTime = Date()
        let totalSize = (try? tempZipURL.resourceValues(forKeys: [.fileSizeKey]).fileSize).map { Double($0) } ?? 0.0
        var lastReportedBytes: Double = 0
        var lastReportTime = startUploadTime

        let success = try await GoogleDriveService.shared.uploadLargeFile(
            localURL: tempZipURL,
            fileName: "\(finalName).capkup",
            pauseCheck: { [weak self] in self?.isPaused ?? false },
            cancelCheck: { [weak self] in self?.isCancelled ?? false }
        ) { [weak self] uploadProgress in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.currentProgress = 0.5 + (uploadProgress * 0.5)
                let pct = Int(uploadProgress * 100)
                
                // Calculate instantaneous speed
                let now = Date()
                let bytesUploaded = totalSize * uploadProgress
                let timeDelta = now.timeIntervalSince(lastReportTime)
                
                if timeDelta > 0.5 {
                    let bytesDelta = bytesUploaded - lastReportedBytes
                    let instantSpeed = bytesDelta / timeDelta
                    lastReportedBytes = bytesUploaded
                    lastReportTime = now
                    
                    // Record speed sample for sparkline
                    self.recordSpeed(bytesPerSec: instantSpeed, totalBytes: totalSize, bytesTransferred: bytesUploaded)
                    
                    let formatter = ByteCountFormatter()
                    formatter.allowedUnits = [.useMB, .useGB, .useKB]
                    formatter.countStyle = .file
                    let speedStr = formatter.string(fromByteCount: Int64(instantSpeed)) + "/s"
                    
                    self.currentFile = "Đang tải lên... \(pct)% • \(speedStr)"
                }
            }
        }

        if success {
            await MainActor.run { self.currentPhase = .verifying }
            self.currentProgress = 1.0
            self.currentFile = "Thành công!"
            Logger.sync.info("Sync thành công Project: \(finalName)")
        } else {
            throw NSError(domain: "CapKupSync", code: 1, userInfo: [NSLocalizedDescriptionKey: "UploadLargeFile returned false without throwing an exception."])
        }
    }
}
