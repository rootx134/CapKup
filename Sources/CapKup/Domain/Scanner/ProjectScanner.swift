import Foundation

class ProjectScanner {
    
    // Quét tìm danh sách các LocalProject
    func scanLocalProjects(in rootURL: URL) async throws -> [LocalProject] {
        let fileManager = FileManager.default
        var projects: [LocalProject] = []
        
        // Quét các thư mục con cấp 1 (mỗi thư mục con là một project CapCut)
        let contents = try fileManager.contentsOfDirectory(at: rootURL, includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey], options: .skipsHiddenFiles)
        
        for url in contents {
            guard let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey]),
                  resourceValues.isDirectory == true else {
                continue
            }
            let projectName = url.lastPathComponent
            let lastMod = resourceValues.contentModificationDate ?? Date()
            
            let isDownloaded = projectName.contains("(CapKup)")
            let createdDate = try? url.resourceValues(forKeys: [.creationDateKey]).creationDate
            
            var status: SyncStatus = .notBackedUp
            var lastSyncedDate: Date? = nil
            
            let metaURL = url.appendingPathComponent(".capkup_sync_meta")
            if let dateString = try? String(contentsOf: metaURL, encoding: .utf8),
               let syncedDate = ISO8601DateFormatter().date(from: dateString.trimmingCharacters(in: .whitespacesAndNewlines)) {
                
                lastSyncedDate = syncedDate
                
                // Project has been synced before. Has it been modified since then?
                // We add a 30 seconds buffer for fast processing
                if lastMod > syncedDate.addingTimeInterval(30) {
                    status = .hasChanges
                } else {
                    status = .synced
                }
            }
            
            // Load giao diện tức thời, size để 0 tạm thời
            let project = LocalProject(name: projectName, rootPath: url.path(percentEncoded: false), totalSize: 0, lastModified: lastMod, status: status)
            project.lastSyncedDate = lastSyncedDate
            project.isDownloaded = isDownloaded
            if isDownloaded {
                project.downloadedAt = createdDate ?? lastMod
            }
            projects.append(project)
        }
        return projects
    }
    
    // Nạp kích thước ngầm cho project
    func asyncCalculateSize(for project: LocalProject) async {
        let url = URL(fileURLWithPath: project.rootPath)
        let fileManager = FileManager.default
        var size = 0
        do {
            size = try await calculateDirectorySize(at: url)
        } catch {}
        
        var totalExternalPaths = Set<String>()
        let possibleJSONs = ["draft_content.json", "draft_meta_info.json", "draft_info.json"]
        
        for jsonName in possibleJSONs {
            let draftContent = url.appendingPathComponent(jsonName)
            if fileManager.fileExists(atPath: draftContent.path) {
                let parsed = CapCutProjectParser.extractExternalMedia(from: draftContent, projectRootURL: url)
                totalExternalPaths.formUnion(parsed)
            }
        }
        
        for mp in totalExternalPaths {
            if let attr = try? fileManager.attributesOfItem(atPath: mp), let sz = attr[.size] as? Int {
                size += sz
            }
        }
        
        let finalSize = size
        await MainActor.run { project.totalSize = finalSize }
    }
    
    // Tính tổng dung lượng thư mục bằng cách đệ quy
    private func calculateDirectorySize(at url: URL) async throws -> Int {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey], options: []) else {
            return 0
        }
        
        var totalSize = 0
        for case let fileURL as URL in enumerator {
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]) {
                totalSize += resourceValues.fileSize ?? 0
            }
        }
        return totalSize
    }
}
