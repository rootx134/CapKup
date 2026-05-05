import SwiftUI
import AppKit

enum LocalSortOption: String, CaseIterable {
    case dateDesc = "Mới nhất"
    case dateAsc = "Cũ nhất"
    case nameAsc = "Tên A-Z"
    case nameDesc = "Tên Z-A"
    case sizeDesc = "Nặng nhất"
    case sizeAsc = "Nhẹ nhất"
}

struct LocalProjectListView: View {
    @State private var errorMessage: String? = nil
    @State private var searchText: String = ""
    @State private var renameTarget: LocalProject? = nil
    @State private var newName: String = ""
    @State private var isShowingRename: Bool = false
    @State private var deleteTarget: LocalProject? = nil
    @State private var isShowingDeleteConfirm: Bool = false
    @State private var sortOption: LocalSortOption = .dateDesc
    @AppStorage("isGridView") private var isGridView: Bool = false
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var scheme
    
    private var sortedAndFilteredProjects: [LocalProject] {
        var result = appState.localProjects
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
            let selectedCount = appState.selectedLocalProjectIDs.count
            HStack(spacing: CKSpacing.sm) {
                // Select all
                Button(action: {
                    let isAllSelected = selectedCount == appState.localProjects.count && !appState.localProjects.isEmpty
                    if isAllSelected {
                        appState.selectedLocalProjectIDs.removeAll()
                    } else {
                        appState.selectedLocalProjectIDs = Set(appState.localProjects.map { $0.id })
                    }
                }) {
                    Image(systemName: selectedCount == appState.localProjects.count && !appState.localProjects.isEmpty ? CKIcon.checkboxOn : CKIcon.checkboxOff)
                        .foregroundColor(CKColor.accentBlue(scheme))
                }
                .buttonStyle(.plain)
                .disabled(appState.localProjects.isEmpty)
                
                if selectedCount > 0 {
                    Text("\("Đã chọn".localized) \(selectedCount)")
                        .font(.caption)
                        .foregroundColor(CKColor.textSecondary(scheme))
                    
                    Button {
                        let selected = appState.localProjects.filter { appState.selectedLocalProjectIDs.contains($0.id) }
                        SyncEngine.shared.enqueueProjects(selected)
                        appState.selectedLocalProjectIDs.removeAll()
                    } label: {
                        Label("Tải lên".localized, systemImage: CKIcon.upload)
                            .font(.caption.weight(.medium))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(CKColor.accentBlue(scheme))
                    
                    // Delete selected projects
                    Button {
                        // Trigger batch delete confirmation
                        self.deleteTarget = nil
                        self.isShowingDeleteConfirm = true
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
                        ForEach(LocalSortOption.allCases, id: \.self) { option in
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
                    Task { await scanProjects() }
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
                .help("Làm mới Máy".localized)
            }
            .padding(.horizontal, CKSpacing.md)
            .padding(.vertical, CKSpacing.sm)
            .background(CKColor.toolbarBackground(scheme))
            
            Divider().opacity(0.3)
            
            // Content
            if appState.localProjects.isEmpty {
                VStack(spacing: CKSpacing.md) {
                    Image(systemName: CKIcon.folderAdd)
                        .font(.system(size: 40))
                        .foregroundColor(CKColor.textSecondary(scheme))
                    Text("Không tìm thấy Project nào trong thư mục".localized)
                        .font(.subheadline)
                        .foregroundColor(CKColor.textSecondary(scheme))
                    if let err = errorMessage {
                        Text("Lỗi: \(err)")
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
                                ProjectCardView(project: project, onRename: {
                                    self.renameTarget = project
                                    self.newName = project.name
                                    self.isShowingRename = true
                                }, onDelete: {
                                    self.deleteTarget = project
                                    self.isShowingDeleteConfirm = true
                                })
                            }
                        }
                        .padding(CKSpacing.md)
                    }
                } else {
                    List(sortedAndFilteredProjects) { project in
                        ProjectRowView(project: project, onRename: {
                            self.renameTarget = project
                            self.newName = project.name
                            self.isShowingRename = true
                        }, onDelete: {
                            self.deleteTarget = project
                            self.isShowingDeleteConfirm = true
                        })
                    }
                }
            }
        }
        .alert("Đổi tên".localized, isPresented: $isShowingRename) {
            TextField("Tên mới".localized, text: $newName)
            Button("Lưu".localized) {
                if let target = renameTarget, !newName.isEmpty {
                    let oldURL = URL(fileURLWithPath: target.rootPath)
                    let newURL = oldURL.deletingLastPathComponent().appendingPathComponent(newName)
                    do {
                        try FileManager.default.moveItem(at: oldURL, to: newURL)
                        target.name = newName
                        target.rootPath = newURL.path
                    } catch {
                        self.errorMessage = "Không thể đổi tên folder: \(error.localizedDescription)"
                    }
                }
            }
            Button("Hủy".localized, role: .cancel) {}
        }
        .confirmationDialog(
            deleteTarget != nil
                ? "Xóa dự án \"\(deleteTarget?.name ?? "")\""
                : "Xóa \(appState.selectedLocalProjectIDs.count) dự án đã chọn",
            isPresented: $isShowingDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Xóa vĩnh viễn".localized, role: .destructive) {
                if let target = deleteTarget {
                    // Single project delete
                    do {
                        try FileManager.default.removeItem(atPath: target.rootPath)
                        appState.localProjects.removeAll { $0.id == target.id }
                    } catch {
                        self.errorMessage = "Lỗi khi xóa: \(error.localizedDescription)"
                    }
                    deleteTarget = nil
                } else {
                    // Batch delete selected projects
                    let selectedProjects = appState.localProjects.filter { appState.selectedLocalProjectIDs.contains($0.id) }
                    for project in selectedProjects {
                        do {
                            try FileManager.default.removeItem(atPath: project.rootPath)
                            appState.localProjects.removeAll { $0.id == project.id }
                        } catch {
                            self.errorMessage = "Lỗi khi xóa \(project.name): \(error.localizedDescription)"
                        }
                    }
                    appState.selectedLocalProjectIDs.removeAll()
                }
            }
            Button("Hủy".localized, role: .cancel) { deleteTarget = nil }
        } message: {
            Text("Hành động này sẽ xóa VĨNH VIỄN thư mục dự án khỏi máy tính. Không thể hoàn tác!".localized)
        }
        .onAppear {
            Task { await scanProjects() }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ProjectDidAutoDeleteLocal"))) { output in
            if let projectId = output.object as? String {
                appState.localProjects.removeAll { $0.id == projectId }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("LocalRefreshRequested"))) { _ in
            Task { await scanProjects() }
        }
    }
    
    // Toolbar icon button
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
    
    private func scanProjects() async {
        guard let url = appState.localFolderURL else { return }
        _ = url.startAccessingSecurityScopedResource()
        defer { url.stopAccessingSecurityScopedResource() }
        
        let scanner = ProjectScanner()
        do {
            self.errorMessage = nil
            let foundProjects = try await scanner.scanLocalProjects(in: url)
            await MainActor.run {
                self.appState.localProjects = foundProjects.sorted(by: { $0.lastModified > $1.lastModified })
                self.appState.crossCheckLocalProjects()
            }
            
            for p in self.appState.localProjects {
                Task.detached {
                    await scanner.asyncCalculateSize(for: p)
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Project Row View (List Mode)
struct ProjectRowView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var scheme
    @ObservedObject var project: LocalProject
    let onRename: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: CKSpacing.sm) {
            Toggle("", isOn: Binding(
                get: { appState.selectedLocalProjectIDs.contains(project.id) },
                set: { isSelected in
                    if isSelected {
                        appState.selectedLocalProjectIDs.insert(project.id)
                    } else {
                        appState.selectedLocalProjectIDs.remove(project.id)
                    }
                }
            ))
            .labelsHidden()
            
            let coverURL = URL(fileURLWithPath: project.rootPath).appendingPathComponent("draft_cover.jpg")
            LocalImageView(url: coverURL)
                .frame(width: 60, height: 34)
                .clipShape(RoundedRectangle(cornerRadius: CKRadius.thumbnail))
                
            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(CKColor.textPrimary(scheme))
                
                HStack(spacing: 4) {
                    Text(formatBytes(project.totalSize))
                    if let date = project.lastSyncedDate, project.status == .synced {
                        Text("• \("Tải lên".localized): \(formatDate(date))")
                    }
                }
                .font(.caption)
                .foregroundColor(CKColor.textSecondary(scheme))
                
                if project.isDownloaded {
                    HStack(spacing: CKSpacing.xs) {
                        Image(systemName: CKIcon.downloaded)
                        Text("Dự án được tải về".localized)
                        if let date = project.downloadedAt {
                            Text("• \(formatDate(date))")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(CKColor.accentCyan)
                }
            }
            Spacer()
            BadgeView(status: project.status)
            
            Button {
                SyncEngine.shared.enqueueProjects([project])
            } label: {
                Label("Tải lên".localized, systemImage: CKIcon.upload)
                    .font(.caption.weight(.medium))
                    .labelStyle(.titleOnly)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(CKColor.accentBlue(scheme))
            .disabled(project.status == .waiting || SyncEngine.shared.uploadQueue.contains(where: {$0.id == project.id}))
        }
        .padding(.vertical, CKSpacing.xs)
        .contextMenu {
            Button {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: project.rootPath)
            } label: {
                Label("Mở thư mục chứa dự án".localized, systemImage: "folder")
            }
            
            Divider()
            
            Button { onRename() } label: {
                Label("Đổi tên".localized, systemImage: CKIcon.rename)
            }
            Button(role: .destructive, action: { onDelete() }) {
                Label("Xoá dự án".localized, systemImage: CKIcon.delete)
            }
        }
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        if bytes == 0 { return "Đang tính dung lượng...".localized }
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

// MARK: - Project Card View (Grid Mode)
struct ProjectCardView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var scheme
    @ObservedObject var project: LocalProject
    let onRename: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: CKSpacing.sm) {
            ZStack(alignment: .topTrailing) {
                let coverURL = URL(fileURLWithPath: project.rootPath).appendingPathComponent("draft_cover.jpg")
                LocalImageView(url: coverURL)
                    .frame(height: 120)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: CKRadius.button))
                
                BadgeView(status: project.status)
                    .padding(6)
            }
            
            Text(project.name)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(CKColor.textPrimary(scheme))
                .lineLimit(1)
            
            Text("\(formatBytes(project.totalSize)) • \(formatDate(project.lastModified))")
                .font(.caption)
                .foregroundColor(CKColor.textSecondary(scheme))
            
            HStack {
                Toggle("", isOn: Binding(
                    get: { appState.selectedLocalProjectIDs.contains(project.id) },
                    set: { isSelected in
                        if isSelected {
                            appState.selectedLocalProjectIDs.insert(project.id)
                        } else {
                            appState.selectedLocalProjectIDs.remove(project.id)
                        }
                    }
                ))
                .labelsHidden()
                
                Spacer()
                
                Button {
                    SyncEngine.shared.enqueueProjects([project])
                } label: {
                    Label("Tải lên".localized, systemImage: CKIcon.upload)
                        .font(.caption.weight(.medium))
                        .labelStyle(.titleOnly)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(CKColor.accentBlue(scheme))
                .disabled(project.status == .waiting || SyncEngine.shared.uploadQueue.contains(where: {$0.id == project.id}))
            }
        }
        .settingsCard(scheme)
        .contextMenu {
            Button {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: project.rootPath)
            } label: {
                Label("Mở thư mục chứa dự án".localized, systemImage: "folder")
            }
            
            Divider()
            
            Button { onRename() } label: {
                Label("Đổi tên".localized, systemImage: CKIcon.rename)
            }
            Button(role: .destructive, action: { onDelete() }) {
                Label("Xoá dự án".localized, systemImage: CKIcon.delete)
            }
        }
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        if bytes == 0 { return "Đang tính...".localized }
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

// MARK: - Local Image View
struct LocalImageView: View {
    let url: URL
    @Environment(\.colorScheme) private var scheme
    
    var body: some View {
        if let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .clipped()
        } else {
            Rectangle()
                .fill(CKColor.cardBackground(scheme))
                .overlay(
                    Image(systemName: CKIcon.film)
                        .font(.caption)
                        .foregroundColor(CKColor.textSecondary(scheme))
                )
        }
    }
}

// MARK: - Badge View (Sync Status)
struct BadgeView: View {
    let status: SyncStatus
    @Environment(\.colorScheme) private var scheme
    
    var body: some View {
        HStack(spacing: CKSpacing.xs) {
            Image(systemName: iconForStatus(status))
                .font(.caption2)
            Text(status.rawValue.localized)
                .font(.caption2.weight(.medium))
        }
        .padding(.horizontal, CKSpacing.sm)
        .padding(.vertical, 3)
        .background(colorForStatus(status).opacity(scheme == .dark ? 0.2 : 0.12))
        .foregroundColor(colorForStatus(status))
        .clipShape(Capsule())
    }
    
    private func iconForStatus(_ status: SyncStatus) -> String {
        switch status {
        case .notBackedUp: return CKIcon.notSynced
        case .hasChanges: return CKIcon.changed
        case .waiting: return CKIcon.waiting
        case .synced: return CKIcon.synced
        case .failed: return CKIcon.failed
        }
    }
    
    private func colorForStatus(_ status: SyncStatus) -> Color {
        switch status {
        case .notBackedUp: return CKColor.textSecondary(scheme)
        case .hasChanges: return CKColor.warningOrange(scheme)
        case .waiting: return CKColor.accentPurple
        case .synced: return CKColor.successGreen(scheme)
        case .failed: return CKColor.dangerRed(scheme)
        }
    }
}
