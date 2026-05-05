import SwiftUI

struct SetupFolderView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var scheme
    
    var body: some View {
        ZStack {
            CKColor.contentBackground(scheme).ignoresSafeArea()
            
            VStack(spacing: CKSpacing.lg) {
                Image(systemName: CKIcon.folderAdd)
                    .font(.system(size: 60))
                    .foregroundStyle(CKColor.logoGradient)
                
                Text("Chọn Thư mục CapCut Offline".localized)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(CKColor.textPrimary(scheme))
                
                Text("Vui lòng chọn ổ đĩa hoặc thư mục chứa các project CapCut để CapKup bắt đầu đồng bộ.".localized)
                    .multilineTextAlignment(.center)
                    .foregroundColor(CKColor.textSecondary(scheme))
                    .padding(.horizontal, 40)
                
                Button(action: selectFolder) {
                    HStack(spacing: CKSpacing.sm) {
                        Image(systemName: CKIcon.folder)
                        Text("Chọn Thư mục CapCut".localized)
                    }
                    .padding(.horizontal, CKSpacing.lg)
                    .padding(.vertical, CKSpacing.md)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(CKColor.accentBlue(scheme))
                .padding(.top, CKSpacing.sm)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            withAnimation { appState.setupFolderSuccess(url: url) }
        }
    }
}
