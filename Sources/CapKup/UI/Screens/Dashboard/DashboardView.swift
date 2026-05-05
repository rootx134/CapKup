import SwiftUI

enum DashboardTab: String, Hashable {
    case local
    case cloud
    case history
    case settings
}

struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var scheme
    @State private var selectedTab: DashboardTab? = .local
    @AppStorage("appLanguage") private var appLanguage: String = "vi"
    // Legacy single-account quota (used if no multi-accounts linked)
    @State private var driveQuotaUsage: Int64 = 0
    @State private var driveQuotaLimit: Int64 = 0
    @State private var isShowingInspector: Bool = true
    
    // Pooled quota from DriveAccountManager (multi-account)
    private var pooledUsage: Int64 {
        let multiAccounts = DriveAccountManager.shared.accounts.filter(\.isActive)
        if multiAccounts.isEmpty { return driveQuotaUsage }
        return DriveAccountManager.shared.totalUsage
    }
    private var pooledLimit: Int64 {
        let multiAccounts = DriveAccountManager.shared.accounts.filter(\.isActive)
        if multiAccounts.isEmpty { return driveQuotaLimit }
        return DriveAccountManager.shared.totalLimit
    }
    
    var body: some View {
        ZStack {
            NavigationSplitView {
                VStack(spacing: 0) {
                // Logo Header
                HStack(spacing: CKSpacing.sm) {
                    ZStack {
                        Image(systemName: CKIcon.logo)
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(CKColor.logoGradient)
                        Image(systemName: CKIcon.logoArrow)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(CKColor.textPrimary(scheme))
                            .offset(y: -1)
                    }
                    Text("CapKup")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(CKColor.textPrimary(scheme))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, CKSpacing.md)
                .padding(.vertical, CKSpacing.md)
                
                List(selection: $selectedTab) {
                    Section("Khu vực ổ đĩa".localized) {
                        NavigationLink(value: DashboardTab.local) {
                            Label("Trên Máy".localized, systemImage: CKIcon.localDrive)
                        }
                        NavigationLink(value: DashboardTab.cloud) {
                            Label("Trên Mây".localized, systemImage: CKIcon.cloud)
                        }
                    }
                    
                    Section("Thống kê".localized) {
                        let totalLocal = appState.localProjects.count
                        let cloudCount = appState.cloudProjects.count
                        let uploaded = appState.localProjects.filter { $0.status == .synced || $0.status == .hasChanges }.count
                        let isPerfect = (uploaded == totalLocal && totalLocal > 0)
                        
                        VStack(alignment: .leading, spacing: CKSpacing.sm) {
                            HStack {
                                Image(systemName: CKIcon.localDrive)
                                    .foregroundColor(CKColor.accentBlue(scheme))
                                Text("Trên Máy:".localized)
                                Spacer()
                                Text("\(totalLocal)")
                            }
                            HStack {
                                Image(systemName: CKIcon.syncedCloud)
                                    .foregroundColor(isPerfect ? CKColor.successGreen(scheme) : CKColor.warningOrange(scheme))
                                Text("Đã Đồng Bộ:".localized)
                                Spacer()
                                Text("\(uploaded)/\(totalLocal)")
                                    .foregroundColor(isPerfect ? CKColor.successGreen(scheme) : CKColor.textPrimary(scheme))
                            }
                            HStack {
                                Image(systemName: CKIcon.cloud)
                                    .foregroundColor(CKColor.accentCyan)
                                Text("Trên Mây:".localized)
                                Spacer()
                                Text("\(cloudCount)")
                            }
                        }.font(.caption)
                    }
                    
                    if pooledLimit > 0 {
                        Section("Google Drive") {
                            VStack(alignment: .leading, spacing: CKSpacing.xs) {
                                let accountCount = DriveAccountManager.shared.accounts.filter(\.isActive).count
                                if accountCount > 1 {
                                    HStack(spacing: CKSpacing.xs) {
                                        Image(systemName: "person.2.fill")
                                            .font(.caption2)
                                            .foregroundColor(CKColor.accentCyan)
                                        Text("\(accountCount) tài khoản")
                                            .font(.caption2)
                                            .foregroundColor(CKColor.textSecondary(scheme))
                                    }
                                } else {
                                    HStack(spacing: CKSpacing.xs) {
                                        Image(systemName: CKIcon.driveQuota)
                                            .font(.caption)
                                            .foregroundColor(CKColor.accentCyan)
                                        Text("Dung lượng".localized)
                                            .font(.caption2)
                                            .foregroundColor(CKColor.textSecondary(scheme))
                                    }
                                }
                                ProgressView(value: Double(pooledUsage), total: Double(pooledLimit))
                                    .tint(Double(pooledUsage)/Double(pooledLimit) > 0.9 ? CKColor.dangerRed(scheme) : CKColor.accentCyan)
                                Text("\(formatBytes(Int(pooledUsage))) / \(formatBytes(Int(pooledLimit)))")
                                    .font(.caption2)
                                    .foregroundColor(CKColor.textSecondary(scheme))
                            }
                        }
                    }
                    
                    
                    Section("Công cụ".localized) {
                        NavigationLink(value: DashboardTab.history) {
                            Label("Lịch sử".localized, systemImage: CKIcon.history)
                        }
                        NavigationLink(value: DashboardTab.settings) {
                            Label("Cài đặt".localized, systemImage: CKIcon.settings)
                        }
                    }
                }
                .navigationTitle("CapKup")
                .id(appLanguage)
            }
            .background(CKColor.sidebarBackground(scheme))
        } detail: {
            ZStack {
                CKColor.contentBackground(scheme).ignoresSafeArea()
                
                Group {
                    switch selectedTab {
                    case .local:
                        LocalProjectListView()
                            .onAppear { SyncEngine.shared.localRootURL = appState.localFolderURL }
                            .id("local-\(appLanguage)")
                    case .cloud:
                        CloudProjectListView()
                            .onAppear { SyncEngine.shared.localRootURL = appState.localFolderURL }
                            .id("cloud-\(appLanguage)")
                    case .settings:
                        SettingsView()
                            .id("settings-\(appLanguage)")
                    case .history:
                        HistoryView()
                            .id("history-\(appLanguage)")
                    case .none:
                        VStack(spacing: CKSpacing.md) {
                            Image(systemName: CKIcon.localDrive)
                                .font(.largeTitle)
                                .foregroundColor(CKColor.textSecondary(scheme))
                            Text("Chọn một tab ở Sidebar".localized)
                                .foregroundColor(CKColor.textSecondary(scheme))
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: selectedTab)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isShowingInspector.toggle()
                        }
                    }) {
                        Label("Tiến trình Đồng bộ".localized, systemImage: CKIcon.inspector)
                    }
                }
            }
            .inspector(isPresented: $isShowingInspector) {
                ProgressInspectorView()
            }
        } // End of NavigationSplitView
        
        // Notifications & Toast Overlay (ZStack layer 2 - Top Level)
        if SyncEngine.shared.showToast,
           let name = SyncEngine.shared.lastCompletedName,
           let action = SyncEngine.shared.lastCompletedAction {
            VStack {
                HStack {
                    Spacer()
                    SyncToast(
                        name: name,
                        action: action,
                        success: SyncEngine.shared.lastCompletedSuccess
                    )
                    .padding(.top, CKSpacing.md)
                    .padding(.trailing, 260) // offset from the inspector
                    // If inspector is hidden, adjust padding
                    .padding(.trailing, isShowingInspector ? 0 : -240)
                }
                Spacer()
            }
            .transition(.move(edge: .top).combined(with: .opacity))
            .zIndex(100)
        }
        
    } // End of ZStack
    .onChange(of: SyncEngine.shared.showToast) { oldVal, newVal in
        if newVal {
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                withAnimation(.easeOut(duration: 0.3)) {
                    SyncEngine.shared.showToast = false
                }
            }
        }
    }
    .onAppear {
        // Request Notification Permission
        NotificationService.shared.requestPermission()
        
        Task {
            let multiAccounts = DriveAccountManager.shared.accounts.filter(\.isActive)
            if multiAccounts.isEmpty {
                // Legacy single-account: fetch quota directly
                if let quota = try? await GoogleDriveService.shared.fetchStorageQuota() {
                    self.driveQuotaUsage = quota.usage
                    self.driveQuotaLimit = quota.limit
                }
            } else {
                // Multi-account: refresh all quotas concurrently
                await DriveAccountManager.shared.refreshAllQuotas()
            }
        }
    }
}
    
    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
