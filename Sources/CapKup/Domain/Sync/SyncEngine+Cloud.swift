import Foundation
import os
import Observation
import AppKit

extension SyncEngine {
    
    // Cloud Queues
    @MainActor
    func enqueueDownloadProjects(_ projects: [CloudProject]) {
        for project in projects {
            self.downloadQueue.append(project)
        }
        if !isSyncing {
            Task { await processDownloadQueue() }
        }
    }
    
    @MainActor
    func enqueueDeleteProjects(_ projects: [CloudProject]) {
        for project in projects {
            self.deleteQueue.append(project)
        }
        if !isSyncing {
            Task { await processDeleteQueue() }
        }
    }
    
    @MainActor
    func dequeueCloudProject(_ project: CloudProject) {
        if let idx = downloadQueue.firstIndex(where: {$0.id == project.id}) {
            downloadQueue.remove(at: idx)
        }
        if let idx = deleteQueue.firstIndex(where: {$0.id == project.id}) {
            deleteQueue.remove(at: idx)
        }
    }
    
    private func generateUniqueURL(baseFolder: URL, folderName: String) -> URL {
        var targetURL = baseFolder.appendingPathComponent(folderName)
        var counter = 1
        while FileManager.default.fileExists(atPath: targetURL.path) {
            targetURL = baseFolder.appendingPathComponent("\(folderName) (\(counter))")
            counter += 1
        }
        return targetURL
    }
    
    func processDownloadQueue() async {
        guard let localRoot = localRootURL else { return }
        
        while let nextProject = await getNextDownload() {
            await MainActor.run { self.activeDownloadProject = nextProject }
            await setSyncing(true)
            await setProgress(0.1, filename: "Bắt đầu tải \(nextProject.name)...")
            
            do {
                let originalName = nextProject.name.replacingOccurrences(of: ".capkup", with: "")
                let baseName = "\(originalName) (CapKup)"
                let customDir = UserDefaults.standard.string(forKey: "customRestoreDirectory") ?? ""
                let rootDirForExtract = customDir.isEmpty ? localRoot : URL(fileURLWithPath: customDir)
                let targetLocalFolder = generateUniqueURL(baseFolder: rootDirForExtract, folderName: baseName)
                
                let tempZip = FileManager.default.temporaryDirectory.appendingPathComponent("dl_\(nextProject.remoteId).capkup")
                let tempExtract = FileManager.default.temporaryDirectory.appendingPathComponent("ex_\(nextProject.remoteId)")
                
                try? FileManager.default.removeItem(at: tempZip)
                try? FileManager.default.removeItem(at: tempExtract)
                try FileManager.default.createDirectory(at: tempExtract, withIntermediateDirectories: true)
                
                await MainActor.run { self.currentPhase = .downloading }
                await setProgress(0.3, filename: "Đang tải dữ liệu nhị phân...")
                let startDownloadTime = Date()
                let totalSize = Double(nextProject.totalSize)
                var lastReportedBytes: Double = 0
                var lastReportTime = startDownloadTime
                
                try await GoogleDriveService.shared.downloadLargeFile(
                    remoteId: nextProject.remoteId,
                    localDestination: tempZip
                ) { [weak self] dlProgress in
                    Task { @MainActor [weak self] in
                        guard let self = self else { return }
                        self.currentProgress = 0.3 + (dlProgress * 0.4)
                        let pct = Int(dlProgress * 100)
                        
                        // Calculate instantaneous speed
                        let now = Date()
                        let bytesDownloaded = totalSize * dlProgress
                        let timeDelta = now.timeIntervalSince(lastReportTime)
                        
                        if timeDelta > 0.5 {
                            let bytesDelta = bytesDownloaded - lastReportedBytes
                            let instantSpeed = bytesDelta / timeDelta
                            lastReportedBytes = bytesDownloaded
                            lastReportTime = now
                            
                            // Record speed sample for sparkline
                            self.recordSpeed(bytesPerSec: instantSpeed, totalBytes: totalSize, bytesTransferred: bytesDownloaded)
                            
                            let formatter = ByteCountFormatter()
                            formatter.allowedUnits = [.useMB, .useGB, .useKB]
                            formatter.countStyle = .file
                            let speedStr = formatter.string(fromByteCount: Int64(instantSpeed)) + "/s"
                            
                            self.currentFile = "Đang tải xuống... \(pct)% • \(speedStr)"
                        }
                    }
                }
                
                await MainActor.run { self.currentPhase = .decrypting }
                await setProgress(0.7, filename: "Đang giải mã AES-256...")
                
                // Decrypt → unzip (supports both encrypted v2 and legacy unencrypted)
                if CapKupCrypto.isEncryptedCapkup(at: tempZip) {
                    // New encrypted format: decrypt first, then unzip
                    let tempDecryptedZip = FileManager.default.temporaryDirectory.appendingPathComponent("dec_\(nextProject.remoteId).zip")
                    defer { try? FileManager.default.removeItem(at: tempDecryptedZip) }
                    try CapKupCrypto.decrypt(inputCapkupURL: tempZip, outputZipURL: tempDecryptedZip)
                    
                    await MainActor.run { self.currentPhase = .extracting }
                    await setProgress(0.8, filename: "Đang giải nén dự án...")
                    try await ZipArchive.unzip(sourceArchive: tempDecryptedZip, destination: targetLocalFolder)
                } else {
                    // Legacy unencrypted .capkup (backward compatible)
                    await MainActor.run { self.currentPhase = .extracting }
                    await setProgress(0.8, filename: "Đang giải nén dự án...")
                    try await ZipArchive.unzip(sourceArchive: tempZip, destination: targetLocalFolder)
                }
                
                // Thu thập media name từ Subfolder
                let mediaFolder = targetLocalFolder.appendingPathComponent("CapKup_Media_Attachments")
                var externalMediaNames = [String]()
                if FileManager.default.fileExists(atPath: mediaFolder.path) {
                    let rootFiles = try FileManager.default.contentsOfDirectory(atPath: mediaFolder.path)
                    for file in rootFiles {
                        // Mọi thứ có đuôi mở rộng
                        if file.contains(".") {
                            externalMediaNames.append(file)
                        }
                    }
                }
                
                await setProgress(0.9, filename: "Khôi phục liên kết JSON...")
                // Restore JSON logic
                let possibleJSONs = ["draft_content.json", "draft_meta_info.json", "draft_info.json"]
                for jsonName in possibleJSONs {
                    let jsonURL = targetLocalFolder.appendingPathComponent(jsonName)
                    if let stringData = try? String(contentsOf: jsonURL, encoding: .utf8) {
                        var patchedString = stringData
                        for mediaName in externalMediaNames {
                            let newAbsPath = mediaFolder.appendingPathComponent(mediaName).path(percentEncoded: false)
                            // Tricky regex replace for path ending with mediaName
                            let pattern = "\"[^\"]*?/" + NSRegularExpression.escapedPattern(for: mediaName) + "\""
                            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                                patchedString = regex.stringByReplacingMatches(in: patchedString, range: NSRange(patchedString.startIndex..., in: patchedString), withTemplate: "\"\(newAbsPath)\"")
                            }
                            
                            // Also handle file://
                            let filePattern = "\"file://[^\"]*?/" + NSRegularExpression.escapedPattern(for: mediaName) + "\""
                            if let regex2 = try? NSRegularExpression(pattern: filePattern, options: .caseInsensitive) {
                                patchedString = regex2.stringByReplacingMatches(in: patchedString, range: NSRange(patchedString.startIndex..., in: patchedString), withTemplate: "\"file://\(newAbsPath)\"")
                            }
                        }
                        try? patchedString.write(to: jsonURL, atomically: true, encoding: .utf8)
                    }
                }
                
                // Write sync meta
                let dateStr = ISO8601DateFormatter().string(from: Date())
                try? dateStr.write(to: targetLocalFolder.appendingPathComponent(".capkup_sync_meta"), atomically: true, encoding: .utf8)
                
                try? FileManager.default.removeItem(at: tempZip)
                
                await setProgress(1.0, filename: "Hoàn tất giải cứu dự án!")
                
                // Record history
                await MainActor.run {
                    SyncHistoryManager.shared.addEntry(SyncHistoryEntry(
                        projectName: nextProject.name,
                        action: .download,
                        result: .success,
                        fileSize: nextProject.totalSize
                    ))
                    self.markCompletion(name: nextProject.name, action: "download", success: true)
                }
            } catch {
                Logger.sync.error("Download Error: \(error.localizedDescription)")
                await MainActor.run {
                    SyncHistoryManager.shared.addEntry(SyncHistoryEntry(
                        projectName: nextProject.name,
                        action: .download,
                        result: .failed,
                        errorMessage: error.localizedDescription
                    ))
                    self.markCompletion(name: nextProject.name, action: "download", success: false)
                }
            }
            
            await setSyncing(false)
            await MainActor.run { 
                self.activeDownloadProject = nil 
                NotificationCenter.default.post(name: Notification.Name("CloudRefreshRequested"), object: nil)
                NotificationCenter.default.post(name: Notification.Name("LocalRefreshRequested"), object: nil)
            }
        }
        
        // Cần xử lý deleteQueue nếu download queue đã cạn
        await processDeleteQueue()
    }
    
    func processDeleteQueue() async {
        while let nextProject = await getNextDelete() {
            await MainActor.run { self.activeDeleteProject = nextProject }
            await setSyncing(true)
            await setProgress(0.5, filename: "Đang xóa \(nextProject.name)...")
            do {
                try await GoogleDriveService.shared.deleteProject(remoteId: nextProject.remoteId)
                await setProgress(1.0, filename: "Đã xóa")
                
                // Record history
                await MainActor.run {
                    SyncHistoryManager.shared.addEntry(SyncHistoryEntry(
                        projectName: nextProject.name,
                        action: .delete,
                        result: .success
                    ))
                    self.markCompletion(name: nextProject.name, action: "delete", success: true)
                }
            } catch {
                Logger.sync.error("Delete Error: \(error.localizedDescription)")
                await MainActor.run {
                    SyncHistoryManager.shared.addEntry(SyncHistoryEntry(
                        projectName: nextProject.name,
                        action: .delete,
                        result: .failed,
                        errorMessage: error.localizedDescription
                    ))
                    self.markCompletion(name: nextProject.name, action: "delete", success: false)
                }
            }
            await setSyncing(false)
            await MainActor.run { 
                self.activeDeleteProject = nil 
                NotificationCenter.default.post(name: Notification.Name("CloudRefreshRequested"), object: nil)
                NotificationCenter.default.post(name: Notification.Name("LocalRefreshRequested"), object: nil)
            }
        }
        await MainActor.run {
            NotificationCenter.default.post(name: Notification.Name("CloudRefreshRequested"), object: nil)
            NotificationCenter.default.post(name: Notification.Name("LocalRefreshRequested"), object: nil)
        }
    }
    
    @MainActor private func getNextDownload() -> CloudProject? {
        if downloadQueue.isEmpty { return nil }
        return downloadQueue.removeFirst()
    }
    
    @MainActor private func getNextDelete() -> CloudProject? {
        if deleteQueue.isEmpty { return nil }
        return deleteQueue.removeFirst()
    }
    
    @MainActor private func setSyncing(_ state: Bool) {
        self.isSyncing = state
    }
    
    @MainActor private func setProgress(_ p: Double, filename: String) {
        self.currentProgress = p
        self.currentFile = filename
    }
}
