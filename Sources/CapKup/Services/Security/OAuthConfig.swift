import Foundation
import os

// MARK: - OAuth Configuration loaded from OAuthConfig.plist
// This file reads client credentials from a PLIST file that is NOT committed to git.
// For open-source distribution: users create their own Google Cloud project
// and provide their own OAuthConfig.plist with their credentials.

struct OAuthConfig {
    let clientID: String
    let clientSecret: String
    let redirectURI: String
    
    // Singleton loaded from OAuthConfig.plist — searches multiple locations
    static let shared: OAuthConfig = {
        // All possible locations to search for OAuthConfig.plist
        var searchPaths: [String] = []
        
        // 1. Inside the app bundle Resources (standard bundle path)
        if let bundlePath = Bundle.main.path(forResource: "OAuthConfig", ofType: "plist") {
            searchPaths.append(bundlePath)
        }
        
        // 2. Inside Contents/ of the app bundle
        let bundleDir = Bundle.main.bundlePath
        searchPaths.append(bundleDir + "/Contents/Resources/OAuthConfig.plist")
        searchPaths.append(bundleDir + "/Contents/OAuthConfig.plist")
        
        // 3. Next to the .app bundle (e.g. /Applications/OAuthConfig.plist)
        let appParent = (bundleDir as NSString).deletingLastPathComponent
        searchPaths.append(appParent + "/OAuthConfig.plist")
        
        // 4. Next to the executable (for swift build / dev mode)
        if let execPath = Bundle.main.executablePath {
            let execDir = (execPath as NSString).deletingLastPathComponent
            searchPaths.append(execDir + "/OAuthConfig.plist")
            // Go up from .build/debug/ to project root
            searchPaths.append(execDir + "/../../OAuthConfig.plist")
            searchPaths.append(execDir + "/../../../OAuthConfig.plist")
        }
        
        // 5. Current working directory (for dev builds)
        searchPaths.append(FileManager.default.currentDirectoryPath + "/OAuthConfig.plist")
        
        // 6. Home directory fallback
        searchPaths.append(NSHomeDirectory() + "/Desktop/CapKupSync/OAuthConfig.plist")
        
        // Try each path
        for path in searchPaths {
            if FileManager.default.fileExists(atPath: path),
               let dict = NSDictionary(contentsOfFile: path) as? [String: String],
               let clientID = dict["ClientID"],
               let clientSecret = dict["ClientSecret"] {
                let redirectURI = dict["RedirectURI"] ?? "com.googleusercontent.apps.\(clientID.components(separatedBy: "-").first ?? ""):/oauth2callback"
                Logger.auth.info("OAuth config loaded from: \(path)")
                return OAuthConfig(clientID: clientID, clientSecret: clientSecret, redirectURI: redirectURI)
            }
        }
        
        // Last resort: show a helpful error but DO NOT crash
        Logger.auth.error("OAuthConfig.plist NOT FOUND in any search path. Authentication will fail.")
        Logger.auth.error("Searched paths: \(searchPaths.joined(separator: ", "))")
        
        // Return empty config — authentication will fail gracefully with a clear error
        return OAuthConfig(
            clientID: "",
            clientSecret: "",
            redirectURI: ""
        )
    }()
    
    var isValid: Bool {
        return !clientID.isEmpty && !clientSecret.isEmpty
    }
}

// MARK: - Centralized Logger
extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.capkup.sync"
    
    static let auth      = Logger(subsystem: subsystem, category: "Auth")
    static let sync      = Logger(subsystem: subsystem, category: "Sync")
    static let drive     = Logger(subsystem: subsystem, category: "GoogleDrive")
    static let thumbnail = Logger(subsystem: subsystem, category: "Thumbnail")
    static let cleanup   = Logger(subsystem: subsystem, category: "Cleanup")
    static let bookmark  = Logger(subsystem: subsystem, category: "Bookmark")
    static let app       = Logger(subsystem: subsystem, category: "App")
}
