import SwiftUI
import Observation

enum AppScreen {
    case login
    case setup
    case dashboard
}

@Observable
class AppState {
    var currentScreen: AppScreen = .login
    var isAuthenticated: Bool = false
    var hasSelectedLocalFolder: Bool = false
    var localFolderURL: URL? = nil
    
    init() {
        if GoogleDriveService.shared.isAuthenticated {
            self.isAuthenticated = true
            
            if let restoredURL = BookmarkManager.shared.restoreBookmark() {
                self.localFolderURL = restoredURL
                self.hasSelectedLocalFolder = true
                self.currentScreen = .dashboard
            } else if let autoDetected = Self.detectCapCutFolder() {
                self.localFolderURL = autoDetected
                self.hasSelectedLocalFolder = true
                try? BookmarkManager.shared.saveBookmark(for: autoDetected)
                self.currentScreen = .dashboard
            } else {
                self.currentScreen = .setup
            }
        }
    }
    
    // Cache cho Trên Máy
    var localProjects: [LocalProject] = []
    var selectedLocalProjectIDs: Set<String> = []
    
    // Cache cho Trên Mây
    var cloudProjects: [CloudProject] = []
    var selectedCloudProjectIDs: Set<String> = []
    var cloudErrorMessage: String? = nil
    
    func loginSuccess() {
        isAuthenticated = true
        
        // Try to auto-detect CapCut project folder
        if !hasSelectedLocalFolder {
            if let autoDetected = Self.detectCapCutFolder() {
                setupFolderSuccess(url: autoDetected)
                return
            }
        }
        
        if hasSelectedLocalFolder {
            currentScreen = .dashboard
        } else {
            currentScreen = .setup
        }
    }
    
    func setupFolderSuccess(url: URL) {
        localFolderURL = url
        hasSelectedLocalFolder = true
        // Save bookmark for sandbox access
        try? BookmarkManager.shared.saveBookmark(for: url)
        currentScreen = .dashboard
    }
    
    func logout() {
        isAuthenticated = false
        currentScreen = .login
    }
    
    var hasFetchedCloud: Bool = false
    
    func crossCheckLocalProjects() {
        guard hasFetchedCloud else { return }
        
        // Build a lookup of cloud project names for fast matching
        let cloudNameSet = Set(cloudProjects.map { $0.name })
        
        for i in 0..<localProjects.count {
            let p = localProjects[i]
            let existsOnCloud = cloudNameSet.contains(p.name)
            
            if existsOnCloud {
                // Project exists on cloud — check if it has local changes
                let metaURL = URL(fileURLWithPath: p.rootPath).appendingPathComponent(".capkup_sync_meta")
                if let dateString = try? String(contentsOf: metaURL, encoding: .utf8),
                   let syncedDate = ISO8601DateFormatter().date(from: dateString.trimmingCharacters(in: .whitespacesAndNewlines)) {
                    // Has sync meta — check modification time
                    if p.lastModified > syncedDate.addingTimeInterval(30) {
                        localProjects[i].status = .hasChanges
                    } else {
                        localProjects[i].status = .synced
                    }
                    localProjects[i].lastSyncedDate = syncedDate
                } else {
                    // No local sync meta but exists on cloud — mark as synced
                    localProjects[i].status = .synced
                }
            } else {
                // Not on cloud — if previously marked synced, reset to notBackedUp
                if p.status == .synced || p.status == .hasChanges {
                    localProjects[i].status = .notBackedUp
                    localProjects[i].lastSyncedDate = nil
                    let metaURL = URL(fileURLWithPath: p.rootPath).appendingPathComponent(".capkup_sync_meta")
                    try? FileManager.default.removeItem(at: metaURL)
                }
            }
        }
    }
    
    // MARK: - Auto-detect CapCut project folder
    // Reads CapCut's own preferences to find the "Save to" draft path
    static func detectCapCutFolder() -> URL? {
        let fm = FileManager.default
        let home = NSHomeDirectory()
        
        // CapCut stores preferences in its sandboxed container
        // Bundle ID: com.lemon.lvoverseas (App Store version)
        let capCutBundleIDs = [
            "com.lemon.lvoverseas",  // App Store
            "com.lemon.lvpro",       // Direct download
        ]
        
        for bundleID in capCutBundleIDs {
            let plistPath = "\(home)/Library/Containers/\(bundleID)/Data/Library/Preferences/com.capcut.CapCut.plist"
            
            guard fm.fileExists(atPath: plistPath),
                  let plistData = fm.contents(atPath: plistPath),
                  let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] else {
                continue
            }
            
            // Priority 1: Current "Save to" path from CapCut Settings
            if let currentPath = plist["GlobalSettings.History.currentCustomDraftPath"] as? String,
               fm.fileExists(atPath: currentPath) {
                return URL(fileURLWithPath: currentPath)
            }
            
            // Priority 2: Previous "Save to" paths (user may have changed drives)
            if let oldPaths = plist["GlobalSettings.History.oldCustomDraftPathList"] as? [String] {
                for oldPath in oldPaths {
                    if fm.fileExists(atPath: oldPath) {
                        return URL(fileURLWithPath: oldPath)
                    }
                }
            }
        }
        
        // Priority 3: Fallback — default CapCut path inside container
        for bundleID in capCutBundleIDs {
            let defaultPath = "\(home)/Library/Containers/\(bundleID)/Data/Movies/CapCut/User Data/Projects/com.lveditor.draft"
            if fm.fileExists(atPath: defaultPath) {
                return URL(fileURLWithPath: defaultPath)
            }
        }
        
        // Priority 4: Non-sandboxed fallback (older CapCut versions)
        let legacyPaths = [
            "\(home)/Movies/CapCut/User Data/Projects/com.lveditor.draft",
            "\(home)/Documents/CapCut/User Data/Projects/com.lveditor.draft",
        ]
        for path in legacyPaths {
            if fm.fileExists(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        
        return nil
    }
}
