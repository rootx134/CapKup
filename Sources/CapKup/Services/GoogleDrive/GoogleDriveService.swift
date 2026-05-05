import Foundation
import AuthenticationServices
import CryptoKit
import os

// MARK: - GoogleUserInfo
// Decoded from Google userinfo endpoint after OAuth to identify the account
struct GoogleUserInfo: Decodable {
    let sub: String          // Unique Google user ID
    let email: String
    let name: String         // Display name
}

enum AuthError: Error, LocalizedError {
    case invalidURL, webSessionFailed, apiError(String), tokenParsingFailed
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid Auth URL"
        case .webSessionFailed: return "ASWebAuthenticationSession failed or cancelled"
        case .apiError(let msg): return "Google API Error: \(msg)"
        case .tokenParsingFailed: return "Could not extract access_token from response"
        }
    }
}

struct DriveQuotaResponse: Codable {
    let storageQuota: StorageQuota
}

struct StorageQuota: Codable {
    let limit: String?
    let usage: String
}

class GoogleDriveService: NSObject {
    static let shared = GoogleDriveService()
    
    // OAuth credentials loaded from OAuthConfig.plist (NOT hardcoded)
    private var config: OAuthConfig { OAuthConfig.shared }
    
    // MARK: - Single-account (legacy) state
    private var accessToken: String? = nil
    private var capKupFolderId: String? = nil
    var isAuthenticated: Bool {
        let hasLegacy = accessToken != nil || KeychainService.read(key: .refreshToken) != nil
        let hasMulti = !DriveAccountManager.shared.accounts.filter(\.isActive).isEmpty
        return hasLegacy || hasMulti
    }

    // MARK: - Multi-account in-memory cache (access tokens only)
    // Maps accountId -> access token (short-lived, not persisted in memory across launches)
    private var multiAccessTokenCache: [String: String] = [:]
    
    // MARK: - Legacy single-account token
    private func getValidAccessToken() async throws -> String {
        let expiry = KeychainService.readDouble(key: .tokenExpiry)
        let now = Date().timeIntervalSince1970
        let currentToken = self.accessToken ?? KeychainService.read(key: .accessToken)
        
        if let token = currentToken, expiry > now + 60 {
            self.accessToken = token
            return token
        }
        
        guard let refreshToken = KeychainService.read(key: .refreshToken) else {
            throw AuthError.apiError("Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.")
        }
        
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        let bodyString = "client_id=\(config.clientID)&client_secret=\(config.clientSecret)&refresh_token=\(refreshToken)&grant_type=refresh_token"
        request.httpBody = bodyString.data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            Logger.auth.error("Token refresh failed, forcing re-login")
            logout()
            throw AuthError.apiError("Phiên bảo mật đã quá hạn quá lâu. Vui lòng đăng nhập lại.")
        }
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let newToken = json["access_token"] as? String {
            self.accessToken = newToken
            KeychainService.save(key: .accessToken, value: newToken)
            if let expiresIn = json["expires_in"] as? TimeInterval {
                KeychainService.saveDouble(key: .tokenExpiry, value: now + expiresIn)
            }
            Logger.auth.info("Token refreshed successfully")
            return newToken
        }
        throw AuthError.apiError("Không thể làm mới token.")
    }

    // MARK: - Per-account token (multi-account)
    func getValidAccessToken(for accountId: String) async throws -> String {
        let expiryKey = KeychainService.tokenExpiryKey(for: accountId)
        let expiryStr = KeychainService.read(rawKey: expiryKey) ?? "0"
        let expiry = Double(expiryStr) ?? 0
        let now = Date().timeIntervalSince1970

        // Return cached in-memory token if still valid
        if let cached = multiAccessTokenCache[accountId], expiry > now + 60 {
            return cached
        }
        // Read from Keychain
        if let stored = KeychainService.read(rawKey: KeychainService.accessTokenKey(for: accountId)),
           expiry > now + 60 {
            multiAccessTokenCache[accountId] = stored
            return stored
        }
        // Refresh using refresh token
        guard let refreshToken = KeychainService.read(rawKey: KeychainService.refreshTokenKey(for: accountId)) else {
            throw AuthError.apiError("Tài khoản \(accountId) hết phiên, cần đăng nhập lại.")
        }
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        let body = "client_id=\(config.clientID)&client_secret=\(config.clientSecret)&refresh_token=\(refreshToken)&grant_type=refresh_token"
        request.httpBody = body.data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AuthError.apiError("Làm mới token thất bại cho tài khoản \(accountId)")
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let newToken = json["access_token"] as? String else {
            throw AuthError.apiError("Không parse được token mới")
        }
        let expiresIn = (json["expires_in"] as? TimeInterval) ?? 3600
        KeychainService.saveToken(accessToken: newToken, refreshToken: nil, expiresIn: expiresIn, for: accountId)
        multiAccessTokenCache[accountId] = newToken
        Logger.auth.info("Token refreshed for account \(accountId)")
        return newToken
    }
    
    private func generateRandomString() -> String {
        var buffer = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        return Data(buffer).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    
    private func generateCodeChallenge(verifier: String) -> String {
        let data = verifier.data(using: .utf8)!
        let hash = SHA256.hash(data: data)
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    
    @MainActor
    func authenticate() async throws -> Bool {
        let codeVerifier = generateRandomString()
        let codeChallenge = generateCodeChallenge(verifier: codeVerifier)
        
        let authURLString = "https://accounts.google.com/o/oauth2/v2/auth?client_id=\(config.clientID)&redirect_uri=\(config.redirectURI)&response_type=code&scope=https://www.googleapis.com/auth/drive.file&code_challenge=\(codeChallenge)&code_challenge_method=S256&access_type=offline&prompt=consent"
        guard let url = URL(string: authURLString) else { throw AuthError.invalidURL }
        
        let callbackScheme = config.redirectURI.components(separatedBy: ":").first ?? ""
        
        let authCode: String = try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) { callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                if let callbackURL = callbackURL, 
                   let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                   let codeItem = components.queryItems?.first(where: { $0.name == "code" }),
                   let code = codeItem.value {
                    continuation.resume(returning: code)
                } else {
                    continuation.resume(throwing: AuthError.webSessionFailed)
                }
            }
            session.presentationContextProvider = self
            session.start()
        }
        
        let urlEncodedCode = authCode.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? authCode
        
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        let bodyString = "client_id=\(config.clientID)&client_secret=\(config.clientSecret)&code=\(urlEncodedCode)&grant_type=authorization_code&redirect_uri=\(config.redirectURI)&code_verifier=\(codeVerifier)"
        request.httpBody = bodyString.data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown HTTP \(response)"
            throw AuthError.apiError(errorMsg)
        }
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let token = json["access_token"] as? String {
            self.accessToken = token
            KeychainService.save(key: .accessToken, value: token)
            if let expiresIn = json["expires_in"] as? TimeInterval {
                KeychainService.saveDouble(key: .tokenExpiry, value: Date().timeIntervalSince1970 + expiresIn)
            }
            if let refreshToken = json["refresh_token"] as? String {
                KeychainService.save(key: .refreshToken, value: refreshToken)
            }
            Logger.auth.info("Authentication successful")
            return true
        }
        
        throw AuthError.tokenParsingFailed
    }
    
    func logout() {
        self.accessToken = nil
        self.capKupFolderId = nil
        KeychainService.deleteAll()
        Logger.auth.info("User logged out, tokens cleared from Keychain")
    }

    // MARK: - Add a new Google account via OAuth
    // Returns the DriveAccount to be registered with DriveAccountManager.
    @MainActor
    func authenticateNewAccount() async throws -> DriveAccount {
        let codeVerifier = generateRandomString()
        let codeChallenge = generateCodeChallenge(verifier: codeVerifier)
        
        // Request drive.file + userinfo scopes
        let scope = "https://www.googleapis.com/auth/drive.file https://www.googleapis.com/auth/userinfo.profile https://www.googleapis.com/auth/userinfo.email"
        let encodedScope = scope.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? scope
        let authURLString = "https://accounts.google.com/o/oauth2/v2/auth?client_id=\(config.clientID)&redirect_uri=\(config.redirectURI)&response_type=code&scope=\(encodedScope)&code_challenge=\(codeChallenge)&code_challenge_method=S256&access_type=offline&prompt=consent"
        guard let url = URL(string: authURLString) else { throw AuthError.invalidURL }

        let callbackScheme = config.redirectURI.components(separatedBy: ":").first ?? ""
        let authCode: String = try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) { callbackURL, error in
                if let error = error { continuation.resume(throwing: error); return }
                if let callbackURL = callbackURL,
                   let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                   let code = components.queryItems?.first(where: { $0.name == "code" })?.value {
                    continuation.resume(returning: code)
                } else {
                    continuation.resume(throwing: AuthError.webSessionFailed)
                }
            }
            session.presentationContextProvider = self
            session.start()
        }

        // Exchange code for tokens
        let urlEncodedCode = authCode.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? authCode
        var tokenReq = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        tokenReq.httpMethod = "POST"
        let body = "client_id=\(config.clientID)&client_secret=\(config.clientSecret)&code=\(urlEncodedCode)&grant_type=authorization_code&redirect_uri=\(config.redirectURI)&code_verifier=\(codeVerifier)"
        tokenReq.httpBody = body.data(using: .utf8)
        tokenReq.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let (tokenData, tokenRes) = try await URLSession.shared.data(for: tokenReq)
        guard let tokenHttp = tokenRes as? HTTPURLResponse, tokenHttp.statusCode == 200,
              let tokenJson = try? JSONSerialization.jsonObject(with: tokenData) as? [String: Any],
              let accessToken = tokenJson["access_token"] as? String else {
            let msg = String(data: tokenData, encoding: .utf8) ?? "Unknown"
            throw AuthError.apiError("Token exchange: \(msg)")
        }
        let expiresIn = (tokenJson["expires_in"] as? TimeInterval) ?? 3600
        let refreshToken = tokenJson["refresh_token"] as? String

        // Fetch user info to get stable user ID (sub) + email
        var userReq = URLRequest(url: URL(string: "https://www.googleapis.com/oauth2/v3/userinfo")!)
        userReq.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (userData, _) = try await URLSession.shared.data(for: userReq)
        guard let userInfo = try? JSONDecoder().decode(GoogleUserInfo.self, from: userData) else {
            throw AuthError.apiError("Không lấy được thông tin người dùng")
        }

        // Save tokens to Keychain keyed by Google user sub
        KeychainService.saveToken(accessToken: accessToken, refreshToken: refreshToken, expiresIn: expiresIn, for: userInfo.sub)
        multiAccessTokenCache[userInfo.sub] = accessToken

        let account = DriveAccount(id: userInfo.sub, email: userInfo.email, displayName: userInfo.name)
        Logger.auth.info("New account linked: \(userInfo.email) (\(userInfo.sub))")
        return account
    }
    
    // MARK: - Ensure CapKup root folder (legacy single-account)
    func ensureRootFolderExists() async throws -> String {
        if let id = capKupFolderId { return id }
        let token = try await getValidAccessToken()
        return try await ensureCapKupFolder(token: token, cacheId: &capKupFolderId)
    }

    // MARK: - Ensure CapKup root folder (per-account)
    func ensureRootFolderExists(for accountId: String) async throws -> String {
        // Check cached folder ID in DriveAccountManager
        if let cached = DriveAccountManager.shared.accounts.first(where: { $0.id == accountId })?.folderId {
            return cached
        }
        let token = try await getValidAccessToken(for: accountId)
        var dummy: String? = nil
        let folderId = try await ensureCapKupFolder(token: token, cacheId: &dummy)
        DriveAccountManager.shared.updateFolderId(folderId, for: accountId)
        return folderId
    }

    // Shared helper to find/create the CapKup folder on Drive
    private func ensureCapKupFolder(token: String, cacheId: inout String?) async throws -> String {
        var components = URLComponents(string: "https://www.googleapis.com/drive/v3/files")!
        components.queryItems = [
            URLQueryItem(name: "q", value: "name='CapKup' and mimeType='application/vnd.google-apps.folder' and trashed=false"),
            URLQueryItem(name: "fields", value: "files(id)")
        ]
        var req = URLRequest(url: components.url!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: req)
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let files = json["files"] as? [[String: Any]],
           let first = files.first, let id = first["id"] as? String {
            cacheId = id
            return id
        }
        // Create if not exists
        var createReq = URLRequest(url: URL(string: "https://www.googleapis.com/drive/v3/files")!)
        createReq.httpMethod = "POST"
        createReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        createReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let meta: [String: Any] = ["name": "CapKup", "mimeType": "application/vnd.google-apps.folder"]
        createReq.httpBody = try JSONSerialization.data(withJSONObject: meta)
        let (cData, _) = try await URLSession.shared.data(for: createReq)
        if let cJson = try? JSONSerialization.jsonObject(with: cData) as? [String: Any],
           let id = cJson["id"] as? String {
            cacheId = id
            return id
        }
        throw AuthError.apiError("Không thể tạo thư mục CapKup trên Drive.")
    }
    
    // ─────────────────────────────────────────────────
    // CHUNKED RESUMABLE UPLOAD — Chunk 8MB, retry 20 times
    // ─────────────────────────────────────────────────
    func uploadLargeFile(
        localURL: URL,
        fileName: String,
        pauseCheck: (() -> Bool)? = nil,
        cancelCheck: (() -> Bool)? = nil,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> Bool {
        let token = try await getValidAccessToken()

        let chunkSize: Int = 8 * 1024 * 1024  // 8MB per chunk
        let fileSize: Int = (try localURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard fileSize > 0 else { throw AuthError.apiError("File rỗng hoặc không đọc được") }

        // Step 1: Init Resumable Session
        let parentId = try await ensureRootFolderExists()
        var initReq = URLRequest(url: URL(string: "https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable")!)
        initReq.httpMethod = "POST"
        initReq.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        initReq.addValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        initReq.addValue(String(fileSize), forHTTPHeaderField: "X-Upload-Content-Length")
        initReq.addValue("application/octet-stream", forHTTPHeaderField: "X-Upload-Content-Type")
        let metadata: [String: Any] = ["name": fileName, "parents": [parentId]]
        initReq.httpBody = try JSONSerialization.data(withJSONObject: metadata)

        let (initData, initRes) = try await URLSession.shared.data(for: initReq)
        guard let initHttp = initRes as? HTTPURLResponse else {
            throw AuthError.apiError("Không lấy được HTTPURLResponse")
        }
        
        guard initHttp.statusCode == 200 else {
            let errorMsg = String(data: initData, encoding: .utf8) ?? "Unknown err"
            Logger.drive.error("Resumable session init failed: \(initHttp.statusCode) - \(errorMsg)")
            throw AuthError.apiError("Gọi API lỗi HTTP \(initHttp.statusCode) (\(errorMsg))")
        }
        
        guard let locationRaw = initHttp.allHeaderFields["Location"] as? String
                ?? initHttp.allHeaderFields["location"] as? String,
              let uploadURL = URL(string: locationRaw)
        else { throw AuthError.apiError("Status 200 nhưng không có Location header") }

        // Store session info for potential resume
        await MainActor.run {
            SyncEngine.shared.activeUploadSessionURL = uploadURL
            SyncEngine.shared.activeUploadFileSize = fileSize
        }

        // Step 2: Send chunks with pause/cancel support
        var offset = 0
        while offset < fileSize {
            // Check cancel before each chunk
            if cancelCheck?() == true {
                Logger.drive.info("Upload cancelled by user at offset \(offset)/\(fileSize)")
                throw CancellationError()
            }
            
            // Check pause — wait in loop until resumed or cancelled
            while pauseCheck?() == true {
                try await Task.sleep(nanoseconds: 500_000_000) // 500ms polling
                if cancelCheck?() == true {
                    Logger.drive.info("Upload cancelled while paused at offset \(offset)/\(fileSize)")
                    throw CancellationError()
                }
            }
            
            let chunkLength = try await uploadSingleChunk(
                offset: offset,
                chunkSize: chunkSize,
                fileSize: fileSize,
                uploadURL: uploadURL,
                localURL: localURL
            )
            
            offset += chunkLength
            let capturedOffset = offset
            await MainActor.run { SyncEngine.shared.activeUploadOffset = capturedOffset }
            let progress = Double(offset) / Double(fileSize)
            progressHandler?(progress)
        }

        return true
    }
    
    // Memory isolation helper for chunk reading and uploading
    private func uploadSingleChunk(offset: Int, chunkSize: Int, fileSize: Int, uploadURL: URL, localURL: URL) async throws -> Int {
        let end = min(offset + chunkSize - 1, fileSize - 1)
        let chunkLength = end - offset + 1
        
        let chunkData = try autoreleasepool { () -> Data in
            let fileHandle = try FileHandle(forReadingFrom: localURL)
            defer { try? fileHandle.close() }
            try fileHandle.seek(toOffset: UInt64(offset))
            return try fileHandle.read(upToCount: chunkLength) ?? Data()
        }
        
        guard !chunkData.isEmpty else { return 0 }
        
        var chunkReq = URLRequest(url: uploadURL)
        chunkReq.httpMethod = "PUT"
        chunkReq.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        chunkReq.setValue(String(chunkLength), forHTTPHeaderField: "Content-Length")
        chunkReq.setValue("bytes \(offset)-\(end)/\(fileSize)", forHTTPHeaderField: "Content-Range")
        
        // Retry chunk up to 20 times
        var success = false
        for attempt in 1...20 {
            do {
                let (_, res) = try await URLSession.shared.upload(for: chunkReq, from: chunkData)
                let statusCode = (res as? HTTPURLResponse)?.statusCode ?? 0
                if statusCode == 308 || statusCode == 200 || statusCode == 201 {
                    success = true
                    break
                } else if statusCode >= 400 && statusCode < 500 && statusCode != 401 && statusCode != 403 && statusCode != 429 {
                    if attempt >= 3 {
                        throw AuthError.apiError("Chunk bị từ chối HTTP \(statusCode)")
                    }
                } else {
                    if attempt == 20 {
                        throw AuthError.apiError("Chunk liên tục thất bại HTTP \(statusCode)")
                    }
                }
            } catch {
                if attempt == 20 { throw error }
                let waitTime = min(UInt64(attempt) * 2, 15)
                try await Task.sleep(nanoseconds: waitTime * 1_000_000_000)
            }
        }
        if !success { throw AuthError.apiError("Chunk upload thất bại không thể phục hồi") }
        
        return chunkLength
    }
    
    // MARK: - Fetch cloud project list (per-account)
    func fetchCloudProjects(for accountId: String) async throws -> [CloudProject] {
        let token = try await getValidAccessToken(for: accountId)
        let parentId = try await ensureRootFolderExists(for: accountId)
        return try await fetchCloudProjectsInternal(token: token, parentId: parentId, accountId: accountId)
    }

    // MARK: - Fetch cloud project list (legacy single-account)
    func fetchCloudProjects() async throws -> [CloudProject] {
        let token = try await getValidAccessToken()
        let parentId = try await ensureRootFolderExists()
        return try await fetchCloudProjectsInternal(token: token, parentId: parentId, accountId: nil)
    }

    private func fetchCloudProjectsInternal(token: String, parentId: String, accountId: String?) async throws -> [CloudProject] {

        var urlComponents = URLComponents(string: "https://www.googleapis.com/drive/v3/files")!
        urlComponents.queryItems = [
            URLQueryItem(name: "q", value: "'\(parentId)' in parents and trashed=false"),
            URLQueryItem(name: "fields", value: "files(id, name, size, modifiedTime)")
        ]
        var request = URLRequest(url: urlComponents.url!)
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw AuthError.apiError("Mất kết nối danh sách")
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let files = json?["files"] as? [[String: Any]] ?? []
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallback = ISO8601DateFormatter()
        var capkupFiles: [[String: Any]] = []
        var thumbMap: [String: String] = [:]
        for f in files {
            let name = f["name"] as? String ?? ""
            let id = f["id"] as? String ?? ""
            if name.hasSuffix(".capkup") {
                capkupFiles.append(f)
            } else if name.hasSuffix("_thumb.jpg") {
                let projectName = String(name.dropLast("_thumb.jpg".count))
                thumbMap[projectName] = id
            }
        }
        var results = [CloudProject]()
        for f in capkupFiles {
            let id = f["id"] as? String ?? ""
            let rawName = f["name"] as? String ?? "Unknown"
            let cleanName = rawName.replacingOccurrences(of: ".capkup", with: "")
            let sizeStr = f["size"] as? String ?? "0"
            let modifiedStr = f["modifiedTime"] as? String ?? ""
            let dt = formatter.date(from: modifiedStr) ?? fallback.date(from: modifiedStr) ?? Date()
            let thumbId = thumbMap[cleanName]
            // Tag project with owning accountId so downloads use the correct token
            results.append(CloudProject(
                name: cleanName,
                remoteId: id,
                totalSize: Int(sizeStr) ?? 0,
                lastModified: dt,
                thumbnailFileId: thumbId,
                ownerAccountId: accountId
            ))
        }
        return results
    }

    // Upload thumbnail to Drive (no chunking needed)
    func uploadThumbnail(localURL: URL, projectName: String) async throws {
        let token = try await getValidAccessToken()
        let parentId = try await ensureRootFolderExists()

        let thumbName = "\(projectName)_thumb.jpg"

        // Delete existing thumbnail if any
        var listReq = URLRequest(url: URL(string: "https://www.googleapis.com/drive/v3/files?q='\(parentId)'+in+parents+and+name='\(thumbName)'+and+trashed=false&fields=files(id)")!)
        listReq.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let (listData, _) = try? await URLSession.shared.data(for: listReq),
           let listJson = try? JSONSerialization.jsonObject(with: listData) as? [String: Any],
           let existingFiles = listJson["files"] as? [[String: Any]],
           let oldId = existingFiles.first?["id"] as? String {
            var delReq = URLRequest(url: URL(string: "https://www.googleapis.com/drive/v3/files/\(oldId)")!)
            delReq.httpMethod = "DELETE"
            delReq.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            _ = try? await URLSession.shared.data(for: delReq)
        }

        // Upload new
        let boundary = UUID().uuidString
        var uploadReq = URLRequest(url: URL(string: "https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart")!)
        uploadReq.httpMethod = "POST"
        uploadReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        uploadReq.setValue("multipart/related; boundary=\"\(boundary)\"", forHTTPHeaderField: "Content-Type")

        let meta = "{\"name\":\"\(thumbName)\",\"parents\":[\"\(parentId)\"]}".data(using: .utf8)!
        let imageData = (try? Data(contentsOf: localURL)) ?? Data()

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/json; charset=UTF-8\r\n\r\n".data(using: .utf8)!)
        body.append(meta)
        body.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--".data(using: .utf8)!)
        uploadReq.httpBody = body

        let (_, res) = try await URLSession.shared.data(for: uploadReq)
        guard let http = res as? HTTPURLResponse, http.statusCode == 200 || http.statusCode == 201 else { return }
    }

    // Fetch raw thumbnail bytes from Drive
    func fetchThumbnailData(remoteId: String) async throws -> Data {
        let token = try await getValidAccessToken()
        var req = URLRequest(url: URL(string: "https://www.googleapis.com/drive/v3/files/\(remoteId)?alt=media")!)
        req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AuthError.apiError("Không tải được thumbnail")
        }
        return data
    }
    
    func deleteProject(remoteId: String) async throws {
        let token = try await getValidAccessToken()
        var request = URLRequest(url: URL(string: "https://www.googleapis.com/drive/v3/files/\(remoteId)")!)
        request.httpMethod = "DELETE"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 204 else {
            throw AuthError.apiError("Giải trừ file thất bại trên Mây")
        }
    }
    
    func renameProject(remoteId: String, newName: String) async throws {
        let token = try await getValidAccessToken()
        var request = URLRequest(url: URL(string: "https://www.googleapis.com/drive/v3/files/\(remoteId)")!)
        request.httpMethod = "PATCH"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let metadata: [String: Any] = ["name": newName + ".capkup"]
        request.httpBody = try JSONSerialization.data(withJSONObject: metadata)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw AuthError.apiError("Đổi tên thất bại trên Mây")
        }
    }
    
    // ─────────────────────────────────────────────────────────────────
    // RESUMABLE DOWNLOAD — HTTP Range Request (resume on disconnect)
    // ─────────────────────────────────────────────────────────────────
    func downloadLargeFile(
        remoteId: String,
        localDestination: URL,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws {
        let token = try await getValidAccessToken()

        var downloadSuccess = false
        var lastError: Error? = nil
        let tmpURL = localDestination.appendingPathExtension("tmp")

        for attempt in 1...20 {
            do {
                let existingBytes: Int64 = (try? tmpURL.resourceValues(forKeys: [.fileSizeKey]).fileSize).flatMap { Int64($0) } ?? 0

                var metaReq = URLRequest(url: URL(string: "https://www.googleapis.com/drive/v3/files/\(remoteId)?fields=size")!)
                metaReq.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                let (metaData, _) = try await URLSession.shared.data(for: metaReq)
                let metaJson = try? JSONSerialization.jsonObject(with: metaData) as? [String: Any]
                let totalSize = Int64(metaJson?["size"] as? String ?? "0") ?? 0

                if totalSize > 0 && existingBytes >= totalSize {
                    downloadSuccess = true
                    break
                }

                if !FileManager.default.fileExists(atPath: tmpURL.path) {
                    FileManager.default.createFile(atPath: tmpURL.path, contents: nil)
                }
                let writeHandle = try FileHandle(forWritingTo: tmpURL)
                try writeHandle.seekToEnd()

                var dlReq = URLRequest(url: URL(string: "https://www.googleapis.com/drive/v3/files/\(remoteId)?alt=media")!)
                dlReq.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                var received: Int64 = existingBytes
                let chunkSize: Int64 = 8 * 1024 * 1024 // 8MB per chunk
                
                while received < totalSize {
                    let end = min(received + chunkSize - 1, totalSize - 1)
                    var req = dlReq
                    req.addValue("bytes=\(received)-\(end)", forHTTPHeaderField: "Range")
                    
                    let (data, res) = try await URLSession.shared.data(for: req)
                    guard let httpRes = res as? HTTPURLResponse, 
                          (httpRes.statusCode == 200 || httpRes.statusCode == 206) else {
                        throw AuthError.apiError("Lỗi tải chunk HTTP \((res as? HTTPURLResponse)?.statusCode ?? 0)")
                    }
                    
                    autoreleasepool {
                        writeHandle.write(data)
                    }
                    
                    received += Int64(data.count)
                    if totalSize > 0 {
                        progressHandler?(Double(received) / Double(totalSize))
                    }
                }
                
                try writeHandle.close()
                downloadSuccess = true
                break
                
            } catch {
                lastError = error
                let waitTime = min(UInt64(attempt) * 2, 15)
                try await Task.sleep(nanoseconds: waitTime * 1_000_000_000)
            }
        }

        if !downloadSuccess {
            throw lastError ?? AuthError.apiError("Download liên tục bị gián đoạn")
        }

        if FileManager.default.fileExists(atPath: localDestination.path) {
            try FileManager.default.removeItem(at: localDestination)
        }
        try FileManager.default.moveItem(at: tmpURL, to: localDestination)
    }
    
    // MARK: - Fetch quota (legacy single-account)
    func fetchStorageQuota() async throws -> (usage: Int64, limit: Int64) {
        let token = try await getValidAccessToken()
        return try await fetchQuotaInternal(token: token)
    }

    // MARK: - Fetch quota (per-account)
    func fetchStorageQuota(for accountId: String) async throws -> (usage: Int64, limit: Int64) {
        let token = try await getValidAccessToken(for: accountId)
        return try await fetchQuotaInternal(token: token)
    }

    private func fetchQuotaInternal(token: String) async throws -> (usage: Int64, limit: Int64) {
        var req = URLRequest(url: URL(string: "https://www.googleapis.com/drive/v3/about?fields=storageQuota")!)
        req.httpMethod = "GET"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AuthError.apiError("Không thể lấy dung lượng Google Drive")
        }
        let res = try JSONDecoder().decode(DriveQuotaResponse.self, from: data)
        let usage = Int64(res.storageQuota.usage) ?? 0
        let limit = Int64(res.storageQuota.limit ?? "0") ?? 0
        return (usage, limit)
    }
}

extension GoogleDriveService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return NSApplication.shared.windows.first ?? ASPresentationAnchor()
    }
}
