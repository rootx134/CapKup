import SwiftUI

@main
struct CapKupApp: App {
    @State private var appState = AppState()
    @AppStorage("appTheme") private var appTheme: String = "dark"
    
    init() {
        // Clean up orphaned *.capkup temp files left by previous crashes
        OrphanedTempCleaner.clean()
        
        // Apply saved theme on launch using NSAppearance (reliable on macOS)
        let saved = UserDefaults.standard.string(forKey: "appTheme") ?? "dark"
        applyTheme(saved)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .frame(minWidth: 800, minHeight: 600)
                .preferredColorScheme(appTheme == "dark" ? .dark : .light)
                .onChange(of: appTheme) { _, newValue in
                    applyTheme(newValue)
                }
        }
        .windowStyle(.hiddenTitleBar)
    }
    
    private func applyTheme(_ theme: String) {
        DispatchQueue.main.async {
            switch theme {
            case "light":
                NSApp.appearance = NSAppearance(named: .aqua)
            case "dark":
                NSApp.appearance = NSAppearance(named: .darkAqua)
            default:
                NSApp.appearance = NSAppearance(named: .darkAqua)
            }
        }
    }
}
