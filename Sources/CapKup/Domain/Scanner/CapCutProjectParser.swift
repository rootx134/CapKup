import Foundation

class CapCutProjectParser {
    
    /// Đọc file JSON của CapCut, quét đệ quy mọi trường thông tin để tìm ra các Link trỏ về file ngoài đời thực (như Desktop, Downloads...)
    static func extractExternalMedia(from jsonURL: URL, projectRootURL: URL) -> Set<String> {
        var externalPaths = Set<String>()
        
        guard let data = try? Data(contentsOf: jsonURL) else {
            return externalPaths
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data, options: []) else {
            return externalPaths
        }
        
        let projectPath = projectRootURL.path(percentEncoded: false)
        
        func traverse(node: Any) {
            if let dict = node as? [String: Any] {
                for value in dict.values {
                    traverse(node: value)
                }
            } else if let array = node as? [Any] {
                for item in array {
                    traverse(node: item)
                }
            } else if let str = node as? String {
                var decodedPath = str
                if str.hasPrefix("file://") {
                    if let url = URL(string: str) {
                        decodedPath = url.path
                    }
                }
                
                if decodedPath.hasPrefix("/") {
                    // Kiểm tra xem nó có nằm ngoài project gốc của CapCut hay không
                    if !decodedPath.hasPrefix(projectPath) {
                        // Kiểm tra xem file có thực sự tồn tại ở ổ cứng không (tránh file rác)
                        var isDir: ObjCBool = false
                        if FileManager.default.fileExists(atPath: decodedPath, isDirectory: &isDir), !isDir.boolValue {
                            externalPaths.insert(decodedPath)
                        }
                    }
                }
            }
        }
        
        traverse(node: json)
        return externalPaths
    }
}
