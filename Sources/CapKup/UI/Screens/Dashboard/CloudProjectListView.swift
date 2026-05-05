import SwiftUI
import AppKit

enum CloudSortOption: String, CaseIterable {
    case dateDesc = "Mới nhất"
    case dateAsc = "Cũ nhất"
    case nameAsc = "Tên A-Z"
    case nameDesc = "Tên Z-A"
    case sizeDesc = "Nặng nhất"
    case sizeAsc = "Nhẹ nhất"
}

struct CloudProjectListView: View {
    @State private var errorMessage: String? = nil
    @State private var searchText: String = ""
    @State private var renameTarget: CloudProject? = nil
    @State private var newName: String = ""
    @State private var isShowingRename: Bool = false
    @State private var sortOption: CloudSortOption = .dateDesc
    @AppStorage("isGridView") private var isGridView: Bool = false
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var scheme
    
    private var sortedAndFilteredProjects: [CloudProject] {
        var result = appState.cloudProjects
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        switch sortOption {
        case .dateDesc:
            result.sort { $0.lastModified > $1.lastModified }
        case .dateAsc:
            result.sort { $0.lastModified < $1.lastModified }
        case .nameAsc:
            result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .nameDesc:
            result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
        case .sizeDesc:
            result.sort { $0.totalSize > $1.totalSize }
        case .sizeAsc:
            result.sort { $0.totalSize < $1.totalSize }
        }
        return result
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            let selectedCount = appState.selectedCloudProjectIDs.count
            HStack(spacing: CKSpacing.sm) {
                // Select all
                Button(action: {
                    let isAllSelected = selectedCount == appState.cloudProjects.count && !appState.cloudProjects.isEmpty
                    if isAllSelected {
                        appState.selectedCloudProjectIDs.removeAll()
                    } else {
                        appState.selectedCloudProjectIDs = Set(appState.cloudProjects.map { $0.id })
                    }
                }) {
                    Image(systemName: selectedCount == appState.cloudProjects.count && !appState.cloudProjects.isEmpty ? CKIcon.checkboxOn : CKIcon.checkboxOff)
                        .foregroundColor(CKColor.accentBlue(scheme))
                }
                .buttonStyle(.plain)
                .disabled(appState.cloudProjects.isEmpty)
                
                if selectedCount > 0 {
                    Text("\("Đã chọn".localized) \(selectedCount)")
                        .font(.caption)
                        .foregroundColor(CKColor.textSecondary(scheme))
                    
                    Button {
                        let selected = appState.cloudProjects.filter { appState.selectedCloudProjectIDs.contains($0.id) }
                        SyncEngine.shared.enqueueDownloadProjects(selected)
                        appState.selectedCloudProjectIDs.removeAll()
                    } label: {
                        Label("Tải xuống".localized, systemImage: CKIcon.download)
                            .font(.caption.weight(.medium))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(CKColor.successGreen(scheme))
                    
                    Button {
                        let selected = appState.cloudProjects.filter { appState.selectedCloudProjectIDs.contains($0.id) }
                        SyncEngine.shared.enqueueDeleteProjects(selected)
                        appState.selectedCloudProjectIDs.removeAll()
                    } label: {
                        Label("Xoá".localized, systemImage: CKIcon.delete)
                            .font(.caption.weight(.medium))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(CKColor.dangerRed(scheme))
                }
                
                Spacer()
                
                // Search field
                HStack(spacing: CKSpacing.xs) {
                    Image(systemName: CKIcon.search)
                        .font(.caption)
                        .foregroundColor(CKColor.textSecondary(scheme))
                    TextField("Tìm dự án...".localized, text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.subheadline)
                }
                .padding(.horizontal, CKSpacing.sm)
                .padding(.vertical, 6)
                .background(CKColor.cardBackground(scheme))
                .clipShape(RoundedRectangle(cornerRadius: CKRadius.button))
                .overlay(
                    RoundedRectangle(cornerRadius: CKRadius.button)
                        .stroke(CKColor.cardBorder(scheme), lineWidth: 1)
                )
                .frame(width: 180)

                // Sort
                Menu {
                    Picker("Sắp xếp", selection: $sortOption) {
                        ForEach(CloudSortOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                } label: {
                    Image(systemName: CKIcon.sort)
                        .font(.subheadline)
                        .foregroundColor(CKColor.textSecondary(scheme))
                        .frame(width: 28, height: 28)
                        .background(CKColor.cardBackground(scheme))
                        .clipShape(RoundedRectangle(cornerRadius: CKRadius.button))
                        .overlay(
                            RoundedRectangle(cornerRadius: CKRadius.button)
                                .stroke(CKColor.cardBorder(scheme), lineWidth: 1)
                        )
                }
                .menuIndicator(.hidden)
                
                // View toggle
                HStack(spacing: 0) {
                    toolbarIconButton(icon: CKIcon.listView, isSelected: !isGridView) { isGridView = false }
                    toolbarIconButton(icon: CKIcon.gridView, isSelected: isGridView) { isGridView = true }
                }
                .background(CKColor.cardBackground(scheme))
                .clipShape(RoundedRectangle(cornerRadius: CKRadius.button))
                .overlay(
                    RoundedRectangle(cornerRadius: CKRadius.button)
                        .stroke(CKColor.cardBorder(scheme), lineWidth: 1)
                )
                
                // Refresh
                Button(action: {
                    Task { await loadCloudProjects() }
                }) {
                    Image(systemName: CKIcon.refresh)
                        .font(.subheadline)
                        .foregroundColor(CKColor.textSecondary(scheme))
                        .frame(width: 28, height: 28)
                        .background(CKColor.cardBackground(scheme))
                        .clipShape(RoundedRectangle(cornerRadius: CKRadius.button))
                        .overlay(
                            RoundedRectangle(cornerRadius: CKRadius.button)
                                .stroke(CKColor.cardBorder(scheme), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .help("Làm mới Mây".localized)
            }
            .padding(.horizontal, CKSpacing.md)
            .padding(.vertical, CKSpacing.sm)
            .background(CKColor.toolbarBackground(scheme))
            
            Divider().opacity(0.3)
            
            // Content
            if appState.cloudProjects.isEmpty {
                VStack(spacing: CKSpacing.md) {
                    Image(systemName: CKIcon.cloudEmpty)
                        .font(.system(size: 40))
                        .foregroundColor(CKColor.textSecondary(scheme))
                    Text("Không có Project nào trên Cloud".localized)
                        .font(.subheadline)
                        .foregroundColor(CKColor.textSecondary(scheme))
                    if let err = appState.cloudErrorMessage {
                        HStack(spacing: CKSpacing.xs) {
                            Image(systemName: CKIcon.failed)
                            Text("Lỗi: \(err)")
                        }
                        .font(.caption)
                        .foregroundColor(CKColor.dangerRed(scheme))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                if isGridView {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200, maximum: 250), spacing: CKSpacing.md)], spacing: CKSpacing.md) {
                            ForEach(sortedAndFilteredProjects) { project in
                                CloudProjectCardView(project: project) {
                                    self.renameTarget = project
                                    self.newName = project.name
                                    self.isShowingRename = true
                                }
                            }
                        }
                        .padding(CKSpacing.md)
                    }
                } else {
                    List(sortedAndFilteredProjects) { project in
                        CloudProjectRowView(project: project) {
                            self.renameTarget = project
                            self.newName = project.name
                            self.isShowingRename = true
                        }
                    }
                }
            }
        }
        .alert("Đổi tên".localized, isPresented: $isShowingRename) {
            TextField("Tên mới".localized, text: $newName)
            Button("Lưu".localized) {
                if let target = renameTarget, !newName.isEmpty {
                    Task {
                        do {
                            let cleanName = newName.replacingOccurrences(of: ".capkup", with: "")
                            try await GoogleDriveService.shared.renameProject(remoteId: target.remoteId, newName: cleanName)
                            await MainActor.run {
                                target.name = cleanName
                            }
                        } catch {
                            await MainActor.run {
                                appState.cloudErrorMessage = "Lỗi đổi tên: \(error.localizedDescription)"
                            }
                        }
                    }
                }
            }
            Button("Hủy".localized, role: .cancel) {}
        }
        .onAppear {
            Task { await loadCloudProjects() }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("CloudRefreshRequested"))) { _ in
            Task { await loadCloudProjects() }
        }
    }
    
    // Toolbar icon button — consistent with Local tab
    private func toolbarIconButton(icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.caption)
                .frame(width: 28, height: 28)
                .background(isSelected ? CKColor.accentBlue(scheme) : Color.clear)
                .foregroundColor(isSelected ? .white : CKColor.textSecondary(scheme))
        }
        .buttonStyle(.plain)
    }
    
    private func loadCloudProjects() async {
        do {
            appState.cloudErrorMessage = nil
            // Use DriveAccountManager to aggregate from all linked accounts.
            // Falls back to legacy single-account if no multi-accounts are configured.
            let foundProjects = try await DriveAccountManager.shared.fetchAllCloudProjects()
            await MainActor.run {
                appState.cloudProjects = foundProjects.sorted(by: { $0.lastModified > $1.lastModified })
                appState.hasFetchedCloud = true
                appState.crossCheckLocalProjects()
            }
        } catch {
            await MainActor.run {
                appState.cloudErrorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Cloud Row View
struct CloudProjectRowView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var scheme
    let project: CloudProject
    let onRename: () -> Void
    
    var body: some View {
        HStack(spacing: CKSpacing.sm) {
            Toggle("", isOn: Binding(
                get: { appState.selectedCloudProjectIDs.contains(project.id) },
                set: { isSelected in
                    if isSelected {
                        appState.selectedCloudProjectIDs.insert(project.id)
                    } else {
                        appState.selectedCloudProjectIDs.remove(project.id)
                    }
                }
            ))
            .labelsHidden()
            
            CloudThumbnailView(project: project)
                .frame(width: 60, height: 34)
                .clipShape(RoundedRectangle(cornerRadius: CKRadius.thumbnail))
                
            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(CKColor.textPrimary(scheme))
                
                HStack(spacing: 4) {
                    Text(formatBytes(project.totalSize))
                    Text("• Sửa: \(formatDate(project.lastModified))")
                }
                .font(.caption)
                .foregroundColor(CKColor.textSecondary(scheme))
            }
            Spacer()
            
            Button {
                SyncEngine.shared.enqueueDownloadProjects([project])
            } label: {
                Label("Tải về".localized, systemImage: CKIcon.download)
                    .font(.caption.weight(.medium))
                    .labelStyle(.titleOnly)
            }
            .buttonStyle(.borderedProminent)
            .tint(CKColor.successGreen(scheme))
            .controlSize(.small)
            .disabled(SyncEngine.shared.downloadQueue.contains(where: {$0.id == project.id}))
        }
        .padding(.vertical, CKSpacing.xs)
        .contextMenu {
            Button {
                if let url = URL(string: "https://drive.google.com/file/d/\(project.remoteId)/view") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Label("Mở trên Google Drive".localized, systemImage: "link")
            }
            
            Divider()
            
            Button { onRename() } label: {
                Label("Đổi tên".localized, systemImage: CKIcon.rename)
            }
            Button(role: .destructive) {
                SyncEngine.shared.enqueueDeleteProjects([project])
            } label: {
                Label("Xoá khỏi Mây".localized, systemImage: CKIcon.delete)
            }
        }
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm dd/MM"
        return formatter.string(from: date)
    }
}

// MARK: - Cloud Card View
struct CloudProjectCardView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var scheme
    let project: CloudProject
    let onRename: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: CKSpacing.sm) {
            CloudThumbnailView(project: project)
                .frame(height: 120)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: CKRadius.button))
            
            Text(project.name)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(CKColor.textPrimary(scheme))
                .lineLimit(1)
            
            Text("\(formatBytes(project.totalSize)) • \(formatDate(project.lastModified))")
                .font(.caption)
                .foregroundColor(CKColor.textSecondary(scheme))
            
            HStack {
                Toggle("", isOn: Binding(
                    get: { appState.selectedCloudProjectIDs.contains(project.id) },
                    set: { isSelected in
                        if isSelected {
                            appState.selectedCloudProjectIDs.insert(project.id)
                        } else {
                            appState.selectedCloudProjectIDs.remove(project.id)
                        }
                    }
                ))
                .labelsHidden()
                
                Spacer()
                
                Button {
                    SyncEngine.shared.enqueueDownloadProjects([project])
                } label: {
                    Label("Tải về".localized, systemImage: CKIcon.download)
                        .font(.caption.weight(.medium))
                        .labelStyle(.titleOnly)
                }
                .buttonStyle(.borderedProminent)
                .tint(CKColor.successGreen(scheme))
                .controlSize(.small)
                .disabled(SyncEngine.shared.downloadQueue.contains(where: {$0.id == project.id}))
            }
        }
        .settingsCard(scheme)
        .contextMenu {
            Button {
                if let url = URL(string: "https://drive.google.com/file/d/\(project.remoteId)/view") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Label("Mở trên Google Drive".localized, systemImage: "link")
            }
            
            Divider()
            
            Button { onRename() } label: {
                Label("Đổi tên".localized, systemImage: CKIcon.rename)
            }
            Button(role: .destructive) {
                SyncEngine.shared.enqueueDeleteProjects([project])
            } label: {
                Label("Xoá khỏi Mây".localized, systemImage: CKIcon.delete)
            }
        }
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM"
        return formatter.string(from: date)
    }
}

// MARK: - Cloud Thumbnail View
struct CloudThumbnailView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var scheme
    let project: CloudProject
    @State private var image: NSImage? = nil

    var body: some View {
        Group {
            if let img = image {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
                    .clipped()
            } else {
                let localMatch = appState.localProjects.first(where: { $0.name == project.name })
                let coverURL = localMatch.map { URL(fileURLWithPath: $0.rootPath).appendingPathComponent("draft_cover.jpg") }
                if let url = coverURL, let nsImg = NSImage(contentsOf: url) {
                    Image(nsImage: nsImg)
                        .resizable()
                        .scaledToFill()
                        .clipped()
                } else {
                    Rectangle()
                        .fill(CKColor.cardBackground(scheme))
                        .overlay(
                            Image(systemName: CKIcon.cloud)
                                .font(.caption)
                                .foregroundColor(CKColor.textSecondary(scheme))
                        )
                }
            }
        }
        .task(id: project.thumbnailFileId) {
            guard project.thumbnailFileId != nil else { return }
            image = await ThumbnailCache.shared.thumbnail(for: project)
        }
    }
}
