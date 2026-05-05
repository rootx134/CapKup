import SwiftUI

// MARK: - Design Tokens for CapKup Sync v2.0
// Unified color system with polished dark mode.
// Dark mode: Deep navy-black base with subtle blue tints for depth.
// Light mode: Clean whites with soft gray cards.

enum CKColor {
    // --- Sidebar ---
    static let sidebarBg = Color("sidebarBg", bundle: nil)
    
    static func sidebarBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x0D1117) : Color(hex: 0xF6F8FA)
    }
    
    static func contentBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x161B22) : Color(hex: 0xFFFFFF)
    }
    
    static func cardBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x1C2333) : Color(hex: 0xF0F2F5)
    }
    
    static func cardBackgroundHover(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x222D3F) : Color(hex: 0xE8EBF0)
    }
    
    static func cardBorder(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x2A3343) : Color(hex: 0xE0E3E8)
    }
    
    static func toolbarBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x11161D) : Color(hex: 0xF8F9FB)
    }
    
    // --- Accent Colors (adaptive, vibrant in dark) ---
    static func accentBlue(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x58A6FF) : Color(hex: 0x2563EB)
    }
    
    static let accentCyan = Color(hex: 0x39D1F5)
    static let accentPurple = Color(hex: 0x8B5CF6)
    
    static func successGreen(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x3FB950) : Color(hex: 0x16A34A)
    }
    
    static func dangerRed(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0xF85149) : Color(hex: 0xDC2626)
    }
    
    static func warningOrange(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0xE3B341) : Color(hex: 0xD97706)
    }
    
    // --- Text Colors ---
    static func textPrimary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0xE6EDF3) : Color(hex: 0x1E293B)
    }
    
    static func textSecondary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x8B949E) : Color(hex: 0x64748B)
    }
    
    // --- Dividers ---
    static func divider(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x21262D) : Color(hex: 0xE5E7EB)
    }
    
    // --- Gradient ---
    static func loginGradient(_ scheme: ColorScheme) -> LinearGradient {
        if scheme == .dark {
            return LinearGradient(
                colors: [Color(hex: 0x0D1117), Color(hex: 0x161B22)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [Color(hex: 0xEFF6FF), Color(hex: 0xF5F3FF)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
    }
    
    static let logoGradient = LinearGradient(
        colors: [Color(hex: 0x39D1F5), Color(hex: 0x8B5CF6)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

// MARK: - Spacing Tokens
enum CKSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
}

// MARK: - Corner Radius Tokens
enum CKRadius {
    static let button: CGFloat = 8
    static let card: CGFloat = 12
    static let badge: CGFloat = 20
    static let thumbnail: CGFloat = 6
}

// MARK: - Color Hex Extension
extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 08) & 0xff) / 255,
            blue: Double((hex >> 00) & 0xff) / 255,
            opacity: alpha
        )
    }
}
