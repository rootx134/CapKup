import SwiftUI

// MARK: - Centralized Icon Set (SF Symbols only)
// All icons used throughout CapKup Sync are defined here for consistency.
// SF Symbols are Apple's vector icon system — resolution-independent, no SVG files needed.

enum CKIcon {
    // --- Sidebar Navigation ---
    static let localDrive      = "externaldrive.fill"
    static let cloud           = "cloud.fill"
    static let settings        = "gearshape.fill"
    
    // --- Actions ---
    static let upload          = "arrow.up.circle.fill"
    static let download        = "arrow.down.circle.fill"
    static let delete          = "trash.fill"
    static let search          = "magnifyingglass"
    static let sort            = "arrow.up.arrow.down"
    static let refresh         = "arrow.clockwise"
    static let rename          = "pencil"
    static let cancel          = "xmark.circle.fill"
    
    // --- View Modes ---
    static let gridView        = "square.grid.2x2.fill"
    static let listView        = "list.bullet"
    
    // --- Selection ---
    static let checkboxOn      = "checkmark.square.fill"
    static let checkboxOff     = "square"
    
    // --- Auth ---
    static let login           = "person.crop.circle.badge.plus"
    static let logout          = "rectangle.portrait.and.arrow.right"
    
    // --- File & Folder ---
    static let folder          = "folder.fill"
    static let folderAdd       = "folder.badge.plus"
    static let film            = "film"
    
    // --- Sync Status Badges ---
    static let synced          = "checkmark.icloud.fill"
    static let notSynced       = "xmark.icloud"
    static let failed          = "exclamationmark.triangle.fill"
    static let waiting         = "clock.fill"
    static let changed         = "arrow.triangle.2.circlepath"
    
    // --- Inspector ---
    static let inspector       = "sidebar.right"
    
    // --- Settings ---
    static let lightMode       = "sun.max.fill"
    static let darkMode        = "moon.fill"
    static let language        = "globe"
    static let warning         = "exclamationmark.triangle.fill"
    static let info            = "info.circle"
    
    // --- Stats ---
    static let stats           = "chart.bar.fill"
    static let driveQuota      = "externaldrive.fill.badge.icloud"
    static let syncedCloud     = "checkmark.icloud.fill"
    static let cloudEmpty      = "icloud.slash"
    
    // --- Logo ---
    static let logo            = "cloud.fill"
    static let logoArrow       = "arrow.up"
    
    // --- Download status ---
    static let downloaded      = "icloud.and.arrow.down"
    
    // --- History ---
    static let history         = "clock.arrow.circlepath"
}
