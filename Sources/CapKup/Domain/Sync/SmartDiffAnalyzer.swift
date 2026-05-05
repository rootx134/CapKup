import Foundation
import CryptoKit

struct DiffResult {
    var toUpload: [ProjectFileEntry] = []
    var toDelete: [ProjectFileEntry] = []
    var unchanged: [ProjectFileEntry] = []
}

class SmartDiffAnalyzer {
    
    /// So sánh thư mục local hiện tại với Manifest được lưu trên đám mây
    func analyze(localRootURL: URL, remoteManifest: ProjectManifest?) async throws -> DiffResult {
        var diff = DiffResult()
        
        // 1. Quét toàn bộ file trong project cục bộ rà soát lại
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: localRootURL, includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey], options: [.skipsHiddenFiles]) else {
            return diff
        }
        
        var currentLocalFiles: [String: ProjectFileEntry] = [:]
        
        for case let fileURL as URL in enumerator {
            let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey])
            if resourceValues.isRegularFile == true {
                // Tạo relative path
                let pathString = fileURL.path(percentEncoded: false)
                let rootString = localRootURL.path(percentEncoded: false)
                let relativePath = pathString.replacingOccurrences(of: rootString, with: "").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                
                let size = resourceValues.fileSize ?? 0
                let modDate = resourceValues.contentModificationDate ?? Date()
                
                let entry = ProjectFileEntry(relativePath: relativePath, size: size, modifiedDate: modDate, fingerprint: nil, remoteFileId: nil)
                currentLocalFiles[relativePath] = entry
            }
        }
        
        // 2. Chấm dứt nhanh nếu chưa có trên mây (Mới upload lần đầu)
        guard let manifest = remoteManifest else {
            diff.toUpload = Array(currentLocalFiles.values)
            return diff
        }
        
        // 3. Đối chiếu 2 chiều
        var remoteFilesDict = Dictionary(uniqueKeysWithValues: manifest.files.map { ($0.relativePath, $0) })
        
        // Xét từng file bị thay đổi trên máy
        for (path, localFile) in currentLocalFiles {
            if let remoteFile = remoteFilesDict[path] {
                // Nếu file tồn tại ở cả 2, kiểm tra metadata (kích thước hoặc thời gian)
                if localFile.isDifferent(from: remoteFile) {
                    // Nếu cần kĩ hơn, chỗ này thêm hàm băm (hashing):
                    // let hash = try await FileHasher.hash(url: fileURL)
                    // if hash != remoteFile.fingerprint { diff.toUpload.append(...) }
                    
                    diff.toUpload.append(localFile)
                } else {
                    diff.unchanged.append(localFile)
                }
                remoteFilesDict.removeValue(forKey: path) // Đánh dấu đã quét
            } else {
                // File mới thêm vào ở local
                diff.toUpload.append(localFile)
            }
        }
        
        // Các file còn thừa trong remoteFilesDict chính là file đã bị xoá ở local
        diff.toDelete = Array(remoteFilesDict.values)
        
        return diff
    }
}
