import SwiftUI
import AppKit

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var scheme
    @AppStorage("appTheme") private var appTheme: String = "dark"
    @AppStorage("appLanguage") private var appLanguage: String = "vi"
    @AppStorage("autoDeleteAfterUpload") private var autoDeleteAfterUpload: Bool = false
    @AppStorage("customRestoreDirectory") private var customRestoreDirectory: String = ""
    
    // Multi-account state
    @State private var isAddingAccount: Bool = false
    @State private var addAccountError: String? = nil
    @State private var accountToRemove: DriveAccount? = nil
    @State private var isShowingRemoveConfirm: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CKSpacing.lg) {
                // Header
                Text("Cài đặt".localized)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(CKColor.textPrimary(scheme))
                    .padding(.bottom, CKSpacing.xs)
                
                // All settings cards
                VStack(spacing: CKSpacing.md) {
                    themeSection
                    languageSection
                    syncSection
                    folderSection
                    restoreFolderSection
                    driveAccountsSection   // NEW: Multi-account
                    versionSection
                    logoutSection
                }
            }
            .padding(CKSpacing.lg)
        }
        .confirmationDialog(
            "Xóa tài khoản \"\(accountToRemove?.email ?? "")\"",
            isPresented: $isShowingRemoveConfirm,
            titleVisibility: .visible
        ) {
            Button("Xóa liên kết".localized, role: .destructive) {
                if let acc = accountToRemove {
                    DriveAccountManager.shared.removeAccount(id: acc.id)
                    accountToRemove = nil
                }
            }
            Button("Hủy".localized, role: .cancel) { accountToRemove = nil }
        } message: {
            Text("Chỉ xóa liên kết trong app. Token được xóa khỏi Keychain. Dữ liệu trên Google Drive không bị ảnh hưởng.".localized)
        }
    }
    
    // MARK: - Theme
    private var themeSection: some View {
        VStack(alignment: .leading, spacing: CKSpacing.sm) {
            sectionHeader(icon: scheme == .dark ? CKIcon.darkMode : CKIcon.lightMode, title: "Giao diện".localized)
            
            HStack(spacing: CKSpacing.sm) {
                segmentButton(title: "Sáng".localized, icon: CKIcon.lightMode, isSelected: appTheme == "light") {
                    appTheme = "light"
                    NSApp.appearance = NSAppearance(named: .aqua)
                }
                segmentButton(title: "Tối".localized, icon: CKIcon.darkMode, isSelected: appTheme == "dark") {
                    appTheme = "dark"
                    NSApp.appearance = NSAppearance(named: .darkAqua)
                }
            }
        }
        .settingsCard(scheme)
    }
    
    // MARK: - Language
    private var languageSection: some View {
        VStack(alignment: .leading, spacing: CKSpacing.sm) {
            sectionHeader(icon: CKIcon.language, title: "Ngôn ngữ".localized)
            
            HStack(spacing: CKSpacing.sm) {
                segmentButton(title: "Tiếng Việt", icon: "character.book.closed", isSelected: appLanguage == "vi") {
                    appLanguage = "vi"
                }
                segmentButton(title: "English", icon: "a.circle", isSelected: appLanguage == "en") {
                    appLanguage = "en"
                }
            }
        }
        .settingsCard(scheme)
    }
    
    // MARK: - Sync
    private var syncSection: some View {
        VStack(alignment: .leading, spacing: CKSpacing.sm) {
            sectionHeader(icon: CKIcon.changed, title: "Đồng bộ".localized)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tự động xóa bản địa sau khi Upload".localized)
                        .font(.subheadline)
                        .foregroundColor(CKColor.textPrimary(scheme))
                    
                    HStack(spacing: CKSpacing.xs) {
                        Image(systemName: CKIcon.warning)
                            .font(.caption2)
                        Text("Giải phóng ổ đĩa — Sẽ xóa hẳn File trên máy".localized)
                            .font(.caption)
                    }
                    .foregroundColor(CKColor.warningOrange(scheme))
                }
                
                Spacer()
                
                Toggle("", isOn: $autoDeleteAfterUpload)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .tint(CKColor.accentBlue(scheme))
            }
        }
        .settingsCard(scheme)
    }
    
    // MARK: - Folder
    private var folderSection: some View {
        VStack(alignment: .leading, spacing: CKSpacing.sm) {
            sectionHeader(icon: CKIcon.folder, title: "Thư mục CapCut".localized)
            
            HStack(spacing: CKSpacing.sm) {
                Text(appState.localFolderURL?.path ?? "Chưa chọn".localized)
                    .font(.subheadline)
                    .foregroundColor(CKColor.textSecondary(scheme))
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Spacer()
                
                Button {
                    selectFolder()
                } label: {
                    Text("Thay đổi".localized)
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, CKSpacing.md)
                        .padding(.vertical, 6)
                        .background(CKColor.cardBackground(scheme))
                        .foregroundColor(CKColor.textPrimary(scheme))
                        .clipShape(RoundedRectangle(cornerRadius: CKRadius.button))
                        .overlay(
                            RoundedRectangle(cornerRadius: CKRadius.button)
                                .stroke(CKColor.cardBorder(scheme), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .settingsCard(scheme)
    }
    
    // MARK: - Restore Folder
    private var restoreFolderSection: some View {
        VStack(alignment: .leading, spacing: CKSpacing.sm) {
            sectionHeader(icon: CKIcon.download, title: "Thư mục Tải về (Tuỳ chọn)".localized)
            
            HStack(spacing: CKSpacing.sm) {
                Text(customRestoreDirectory.isEmpty ? "Mặc định (Thư mục CapCut, Tự động tìm)".localized : customRestoreDirectory)
                    .font(.subheadline)
                    .foregroundColor(CKColor.textSecondary(scheme))
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Spacer()
                
                if !customRestoreDirectory.isEmpty {
                    Button {
                        customRestoreDirectory = ""
                    } label: {
                        Text("Xoá".localized)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(CKColor.dangerRed(scheme))
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, CKSpacing.xs)
                }
                
                Button {
                    selectRestoreFolder()
                } label: {
                    Text("Thay đổi".localized)
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, CKSpacing.md)
                        .padding(.vertical, 6)
                        .background(CKColor.cardBackground(scheme))
                        .foregroundColor(CKColor.textPrimary(scheme))
                        .clipShape(RoundedRectangle(cornerRadius: CKRadius.button))
                        .overlay(
                            RoundedRectangle(cornerRadius: CKRadius.button)
                                .stroke(CKColor.cardBorder(scheme), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .settingsCard(scheme)
    }
    
    // MARK: - Drive Accounts (Multi-account)
    private var driveAccountsSection: some View {
        VStack(alignment: .leading, spacing: CKSpacing.sm) {
            sectionHeader(icon: "person.2.fill", title: "Tài khoản Google Drive".localized)
            
            let accounts = DriveAccountManager.shared.accounts
            
            if accounts.isEmpty {
                Text("Chưa có tài khoản nào được liên kết. Sử dụng nút đăng nhập bên dưới để thêm.".localized)
                    .font(.caption)
                    .foregroundColor(CKColor.textSecondary(scheme))
            } else {
                ForEach(accounts) { account in
                    accountRow(account)
                    if account.id != accounts.last?.id {
                        Divider().opacity(0.3)
                    }
                }
            }
            
            // Error message
            if let err = addAccountError {
                HStack(spacing: CKSpacing.xs) {
                    Image(systemName: CKIcon.failed)
                    Text(err)
                }
                .font(.caption)
                .foregroundColor(CKColor.dangerRed(scheme))
            }
            
            // Add account button
            Button {
                addAccountError = nil
                isAddingAccount = true
                Task {
                    do {
                        let newAccount = try await GoogleDriveService.shared.authenticateNewAccount()
                        await MainActor.run {
                            DriveAccountManager.shared.addAccount(newAccount)
                            isAddingAccount = false
                        }
                        // Fetch quota for the new account
                        await DriveAccountManager.shared.refreshAllQuotas()
                    } catch {
                        await MainActor.run {
                            addAccountError = error.localizedDescription
                            isAddingAccount = false
                        }
                    }
                }
            } label: {
                HStack(spacing: CKSpacing.sm) {
                    if isAddingAccount {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: "plus.circle.fill")
                    }
                    Text(isAddingAccount ? "Đang đăng nhập...".localized : "Thêm tài khoản".localized)
                        .font(.subheadline.weight(.medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(CKColor.accentBlue(scheme).opacity(0.15))
                .foregroundColor(CKColor.accentBlue(scheme))
                .clipShape(RoundedRectangle(cornerRadius: CKRadius.button))
                .overlay(
                    RoundedRectangle(cornerRadius: CKRadius.button)
                        .stroke(CKColor.accentBlue(scheme).opacity(0.4), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(isAddingAccount)
        }
        .settingsCard(scheme)
    }
    
    @ViewBuilder
    private func accountRow(_ account: DriveAccount) -> some View {
        HStack(spacing: CKSpacing.sm) {
            // Avatar circle with initial
            ZStack {
                Circle()
                    .fill(CKColor.accentBlue(scheme).opacity(0.2))
                    .frame(width: 36, height: 36)
                Text(String(account.displayName.prefix(1)).uppercased())
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(CKColor.accentBlue(scheme))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(account.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(CKColor.textPrimary(scheme))
                Text(account.email)
                    .font(.caption)
                    .foregroundColor(CKColor.textSecondary(scheme))
                
                // Quota bar
                if account.quotaLimit > 0 {
                    HStack(spacing: CKSpacing.xs) {
                        ProgressView(value: account.usageRatio)
                            .tint(account.usageRatio > 0.9 ? CKColor.dangerRed(scheme) : CKColor.accentCyan)
                            .frame(width: 80)
                        Text("\(formatBytes(Int(account.quotaUsage))) / \(formatBytes(Int(account.quotaLimit)))")
                            .font(.caption2)
                            .foregroundColor(CKColor.textSecondary(scheme))
                    }
                } else {
                    Text("Nhấn làm mới để xem dung lượng".localized)
                        .font(.caption2)
                        .foregroundColor(CKColor.textSecondary(scheme))
                }
            }
            
            Spacer()
            
            // Active toggle
            Toggle("", isOn: Binding(
                get: { account.isActive },
                set: { _ in DriveAccountManager.shared.toggleActive(id: account.id) }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            .tint(CKColor.successGreen(scheme))
            .scaleEffect(0.8)
            
            // Remove button
            Button {
                accountToRemove = account
                isShowingRemoveConfirm = true
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(CKColor.dangerRed(scheme))
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, CKSpacing.xs)
    }
    
    // MARK: - Version
    private var versionSection: some View {
        HStack {
            sectionHeader(icon: CKIcon.info, title: "Thông tin phiên bản".localized)
            Spacer()
            
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.1.0"
            
            Text("v\(version)")
                .font(.subheadline.weight(.semibold).monospaced())
                .foregroundColor(CKColor.accentBlue(scheme))
                .padding(.horizontal, CKSpacing.sm)
                .padding(.vertical, 4)
                .background(CKColor.accentBlue(scheme).opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: CKRadius.badge))
        }
        .settingsCard(scheme)
    }
    
    // MARK: - Logout
    private var logoutSection: some View {
        Button {
            withAnimation { appState.logout() }
        } label: {
            HStack {
                Spacer()
                Image(systemName: CKIcon.logout)
                    .font(.subheadline)
                Text("Đăng xuất".localized)
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }
            .padding(.vertical, 12)
            .foregroundColor(.white)
            .background(CKColor.dangerRed(scheme))
            .clipShape(RoundedRectangle(cornerRadius: CKRadius.card))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Shared Components
    
    private func sectionHeader(icon: String, title: String) -> some View {
        Label {
            Text(title)
                .font(.subheadline.weight(.semibold))
        } icon: {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(CKColor.accentBlue(scheme))
        }
        .foregroundColor(CKColor.textPrimary(scheme))
    }
    
    private func segmentButton(title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                Text(title)
                    .font(.subheadline.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                Group {
                    if isSelected {
                        CKColor.accentBlue(scheme)
                    } else {
                        scheme == .dark ? Color(hex: 0x0D1117) : Color.white.opacity(0.8)
                    }
                }
            )
            .foregroundColor(isSelected ? .white : CKColor.textSecondary(scheme))
            .clipShape(RoundedRectangle(cornerRadius: CKRadius.button))
            .overlay(
                RoundedRectangle(cornerRadius: CKRadius.button)
                    .stroke(isSelected ? Color.clear : CKColor.cardBorder(scheme), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Chọn thư mục Drafts"
        
        if panel.runModal() == .OK, let url = panel.url {
            appState.localFolderURL = url
        }
    }
    
    private func selectRestoreFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Chọn thư mục giải nén"
        if panel.runModal() == .OK, let url = panel.url {
            customRestoreDirectory = url.path
        }
    }

    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// MARK: - Settings Card Modifier
extension View {
    func settingsCard(_ scheme: ColorScheme) -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(CKSpacing.md)
            .background(CKColor.cardBackground(scheme))
            .clipShape(RoundedRectangle(cornerRadius: CKRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: CKRadius.card)
                    .stroke(CKColor.cardBorder(scheme), lineWidth: scheme == .dark ? 1 : 0.5)
            )
    }
}
