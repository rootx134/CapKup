import Foundation
import CryptoKit

// MARK: - CapKup Encrypted Archive Format (Streaming v3)
//
// File structure (.capkup):
// ┌──────────────────────────────────────┐
// │ Magic bytes: "CAPKUP" (6 bytes)      │
// │ Version: 0x03 (1 byte)               │
// │ Flags: 0x01 = encrypted (1 byte)     │
// │ Salt (32 bytes) - for key derivation │
// ├──────────────────────────────────────┤
// │ CHUNK 1:                             │
// │   Length: UInt32 (4 bytes)           │
// │   Nonce: 12 bytes                    │
// │   Payload: Ciphertext + 16 bytes Tag │
// ├──────────────────────────────────────┤
// │ CHUNK 2: ...                         │
// └──────────────────────────────────────┘

enum CapKupCrypto {
    
    static let magic: [UInt8] = [0x43, 0x41, 0x50, 0x4B, 0x55, 0x50]
    static let versionV2: UInt8 = 0x02 // Legacy memory-based format
    static let versionV3: UInt8 = 0x03 // Streaming format
    static let flagEncrypted: UInt8 = 0x01
    static let v3HeaderSize = 6 + 1 + 1 + 32 // magic + version + flags + salt = 40 bytes
    
    static let chunkSize = 1024 * 1024 * 2 // 2MB memory footprint
    
    private static let appSalt = "com.capkup.sync.aes256gcm.v2".data(using: .utf8)!
    
    // MARK: - Key Derivation
    private static func deriveKey(userSecret: String, salt: Data) -> SymmetricKey {
        let inputKeyMaterial = SymmetricKey(data: userSecret.data(using: .utf8)!)
        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: inputKeyMaterial,
            salt: salt,
            info: appSalt,
            outputByteCount: 32
        )
    }
    
    private static func getUserSecret() -> String? {
        return KeychainService.read(key: .refreshToken)
    }
    
    // MARK: - Encrypt ZIP → .capkup (Streaming)
    // Memory efficient: Reads and encrypts in 2MB chunks. Peak RAM ~5MB.
    static func encrypt(inputZipURL: URL, outputCapkupURL: URL) throws {
        guard let userSecret = getUserSecret() else { throw CryptoError.noUserSecret }
        
        // Remove output if exists and create empty file
        try? FileManager.default.removeItem(at: outputCapkupURL)
        FileManager.default.createFile(atPath: outputCapkupURL.path, contents: nil)
        
        let inFile = try FileHandle(forReadingFrom: inputZipURL)
        defer { try? inFile.close() }
        
        let outFile = try FileHandle(forWritingTo: outputCapkupURL)
        defer { try? outFile.close() }
        
        var salt = Data(count: 32)
        _ = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!) }
        
        let key = deriveKey(userSecret: userSecret, salt: salt)
        
        // Write header (40 bytes)
        var header = Data()
        header.append(contentsOf: magic)
        header.append(versionV3)
        header.append(flagEncrypted)
        header.append(salt)
        outFile.write(header)
        
        // Stream chunks
        while true {
            let isDone = try autoreleasepool { () -> Bool in
                guard let chunk = try inFile.read(upToCount: chunkSize), !chunk.isEmpty else {
                    return true // End of file
                }
                
                let nonce = AES.GCM.Nonce()
                let sealedBox = try AES.GCM.seal(chunk, using: key, nonce: nonce)
                
                // Chunk structure: 4 bytes length + 12 bytes nonce + ciphertext + 16 bytes tag
                let payload = sealedBox.ciphertext + sealedBox.tag
                var chunkLength = UInt32(payload.count).littleEndian
                
                var chunkHeader = Data()
                chunkHeader.append(Data(bytes: &chunkLength, count: 4))
                chunkHeader.append(contentsOf: nonce)
                
                outFile.write(chunkHeader)
                outFile.write(payload)
                return false
            }
            if isDone { break }
        }
    }
    
    // MARK: - Direct Folder Stream Encrypt → .capkup (Pipe streaming)
    // Runs zip stdout directly into AES-256 without 50GB temp file on disk!
    static func encryptFromDirectory(sourceDir: URL, outputCapkupURL: URL) throws {
        guard let userSecret = getUserSecret() else { throw CryptoError.noUserSecret }
        
        try? FileManager.default.removeItem(at: outputCapkupURL)
        FileManager.default.createFile(atPath: outputCapkupURL.path, contents: nil)
        
        let outFile = try FileHandle(forWritingTo: outputCapkupURL)
        defer { try? outFile.close() }
        
        var salt = Data(count: 32)
        _ = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!) }
        let key = deriveKey(userSecret: userSecret, salt: salt)
        
        // Write header
        var header = Data()
        header.append(contentsOf: magic)
        header.append(versionV3)
        header.append(flagEncrypted)
        header.append(salt)
        outFile.write(header)
        
        let zipProcess = Process()
        zipProcess.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        zipProcess.currentDirectoryURL = sourceDir
        zipProcess.arguments = ["-r", "-X", "-0", "-q", "-", "."]
        
        let pipe = Pipe()
        zipProcess.standardOutput = pipe
        
        try zipProcess.run()
        let pipeHandle = pipe.fileHandleForReading
        
        while true {
            let isDone = try autoreleasepool { () -> Bool in
                guard let chunk = try pipeHandle.read(upToCount: chunkSize), !chunk.isEmpty else {
                    return true
                }
                
                let nonce = AES.GCM.Nonce()
                let sealedBox = try AES.GCM.seal(chunk, using: key, nonce: nonce)
                
                let payload = sealedBox.ciphertext + sealedBox.tag
                var chunkLength = UInt32(payload.count).littleEndian
                
                var chunkHeader = Data()
                chunkHeader.append(Data(bytes: &chunkLength, count: 4))
                chunkHeader.append(contentsOf: nonce)
                
                outFile.write(chunkHeader)
                outFile.write(payload)
                return false
            }
            if isDone { break }
        }
        
        zipProcess.waitUntilExit()
        if zipProcess.terminationStatus != 0 {
            throw CryptoError.encryptionFailed
        }
    }
    
    // MARK: - Decrypt .capkup → ZIP (Streaming)
    // Memory efficient: Reads and decrypts chunk by chunk directly to disk.
    static func decrypt(inputCapkupURL: URL, outputZipURL: URL) throws {
        guard let userSecret = getUserSecret() else { throw CryptoError.noUserSecret }
        
        let inFile = try FileHandle(forReadingFrom: inputCapkupURL)
        defer { try? inFile.close() }
        
        guard let magicBytes = try inFile.read(upToCount: 6), [UInt8](magicBytes) == magic else {
            throw CryptoError.notEncrypted
        }
        
        guard let versionData = try inFile.read(upToCount: 1), let flagsData = try inFile.read(upToCount: 1) else {
            throw CryptoError.invalidFormat
        }
        
        guard flagsData[0] == flagEncrypted else { throw CryptoError.notEncrypted }
        
        if versionData[0] == versionV2 {
            // Fallback for V2 (Memory Bound)
            try inFile.close()
            let data = try decryptV2InMemory(inputCapkupURL: inputCapkupURL, userSecret: userSecret)
            try data.write(to: outputZipURL)
            return
        }
        
        guard versionData[0] == versionV3 else { throw CryptoError.unsupportedVersion }
        
        guard let salt = try inFile.read(upToCount: 32), salt.count == 32 else {
            throw CryptoError.invalidFormat
        }
        
        let key = deriveKey(userSecret: userSecret, salt: salt)
        
        // Prepare output
        try? FileManager.default.removeItem(at: outputZipURL)
        FileManager.default.createFile(atPath: outputZipURL.path, contents: nil)
        let outFile = try FileHandle(forWritingTo: outputZipURL)
        defer { try? outFile.close() }
        
        // Read chunks
        while true {
            let isDone = try autoreleasepool { () -> Bool in
                guard let lengthData = try inFile.read(upToCount: 4), lengthData.count == 4 else {
                    return true // end of file
                }
                let payloadLength = Int(lengthData.withUnsafeBytes { $0.load(as: UInt32.self).littleEndian })
                
                guard let nonceData = try inFile.read(upToCount: 12), nonceData.count == 12 else {
                    throw CryptoError.invalidFormat
                }
                
                guard let payload = try inFile.read(upToCount: payloadLength), payload.count == payloadLength else {
                    throw CryptoError.invalidFormat
                }
                
                let nonce = try AES.GCM.Nonce(data: nonceData)
                let tagSize = 16
                let ciphertext = payload.prefix(payload.count - tagSize)
                let tag = payload.suffix(tagSize)
                
                let sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
                let plainChunk = try AES.GCM.open(sealedBox, using: key)
                
                outFile.write(plainChunk)
                return false
            }
            if isDone { break }
        }
    }
    
    // MARK: - Legacy V2 Decryptor (loads everything into RAM)
    private static func decryptV2InMemory(inputCapkupURL: URL, userSecret: String) throws -> Data {
        let fileData = try Data(contentsOf: inputCapkupURL)
        let salt = fileData[8..<40]                          // 32 bytes
        let nonceBytes = fileData[40..<52]                   // 12 bytes
        let encryptedPayload = fileData[52...]               // rest
        
        let key = deriveKey(userSecret: userSecret, salt: Data(salt))
        let nonce = try AES.GCM.Nonce(data: nonceBytes)
        
        let tagSize = 16
        let ciphertext = encryptedPayload.prefix(encryptedPayload.count - tagSize)
        let tag = encryptedPayload.suffix(tagSize)
        
        let sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
        return try AES.GCM.open(sealedBox, using: key)
    }
    
    // MARK: - Check if file is CapKup encrypted format
    static func isEncryptedCapkup(at url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        guard let header = try? handle.read(upToCount: 8), header.count >= 8 else { return false }
        let fileMagic = [UInt8](header[0..<6])
        return fileMagic == magic && header[7] == flagEncrypted
    }
    
    // MARK: - Errors
    enum CryptoError: Error, LocalizedError {
        case noUserSecret
        case invalidFormat
        case notEncrypted
        case unsupportedVersion
        case decryptionFailed
        case encryptionFailed
        
        var errorDescription: String? {
            switch self {
            case .noUserSecret: return "No user credentials found. Please login again."
            case .invalidFormat: return "Invalid .capkup file format."
            case .notEncrypted: return "File is not encrypted (legacy format)."
            case .unsupportedVersion: return "Unsupported .capkup version."
            case .decryptionFailed: return "Decryption failed. Wrong account?"
            case .encryptionFailed: return "Stream encryption failed."
            }
        }
    }
}
