import Foundation
import CryptoKit

class FileHasher {
    static func hash(url: URL) async throws -> String {
        return try await Task.detached(priority: .background) {
            let fileHandle = try FileHandle(forReadingFrom: url)
            defer { try? fileHandle.close() }
            
            var hasher = SHA256()
            while let chunk = try fileHandle.read(upToCount: 8 * 1024 * 1024) { // Đọc chunk 8MB
                hasher.update(data: chunk)
            }
            let digest = hasher.finalize()
            return digest.compactMap { String(format: "%02x", $0) }.joined()
        }.value
    }
}
