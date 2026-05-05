import SwiftUI

struct HistoryView: View {
    @Bindable var historyManager = SyncHistoryManager.shared
    @Environment(\.colorScheme) private var scheme
    @AppStorage("appLanguage") private var appLanguage: String = "vi"
    @State private var filterAction: SyncHistoryEntry.SyncAction? = nil
    
    private var filteredEntries: [SyncHistoryEntry] {
        if let filter = filterAction {
            return historyManager.entries.filter { $0.action == filter }
        }
        return historyManager.entries
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: CKSpacing.md) {
                Image(systemName: CKIcon.history)
                    .foregroundColor(CKColor.accentPurple)
                Text("Lịch sử".localized)
                    .font(.title2.weight(.bold))
                    .foregroundColor(CKColor.textPrimary(scheme))
                
                Spacer()
                
                // Filter pills
                HStack(spacing: CKSpacing.xs) {
                    FilterPill(title: "Tất cả".localized, isActive: filterAction == nil) {
                        filterAction = nil
                    }
                    FilterPill(title: "Tải lên".localized, isActive: filterAction == .upload, color: CKColor.accentBlue(scheme)) {
                        filterAction = .upload
                    }
                    FilterPill(title: "Tải về".localized, isActive: filterAction == .download, color: CKColor.successGreen(scheme)) {
                        filterAction = .download
                    }
                    FilterPill(title: "Xoá".localized, isActive: filterAction == .delete, color: CKColor.dangerRed(scheme)) {
                        filterAction = .delete
                    }
                }
                
                if !historyManager.entries.isEmpty {
                    Button {
                        historyManager.clearHistory()
                    } label: {
                        Label("Xoá lịch sử".localized, systemImage: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .tint(CKColor.dangerRed(scheme))
                    .controlSize(.small)
                }
            }
            .padding(.horizontal, CKSpacing.md)
            .padding(.vertical, CKSpacing.sm)
            .background(CKColor.toolbarBackground(scheme))
            
            Divider().opacity(0.3)
            
            // Content
            if filteredEntries.isEmpty {
                VStack(spacing: CKSpacing.md) {
                    Image(systemName: CKIcon.history)
                        .font(.system(size: 40))
                        .foregroundColor(CKColor.textSecondary(scheme))
                    Text("Chưa có lịch sử đồng bộ".localized)
                        .font(.subheadline)
                        .foregroundColor(CKColor.textSecondary(scheme))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                List(filteredEntries) { entry in
                    HistoryEntryRow(entry: entry)
                }
                .listStyle(.inset)
            }
        }
        .id(appLanguage)
    }
}

// MARK: - Filter Pill
private struct FilterPill: View {
    let title: String
    let isActive: Bool
    var color: Color = .primary
    let action: () -> Void
    @Environment(\.colorScheme) private var scheme
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.medium))
                .padding(.horizontal, CKSpacing.sm)
                .padding(.vertical, 4)
                .background(isActive ? color.opacity(0.2) : CKColor.cardBackground(scheme).opacity(0.5))
                .foregroundColor(isActive ? color : CKColor.textSecondary(scheme))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - History Entry Row
private struct HistoryEntryRow: View {
    let entry: SyncHistoryEntry
    @Environment(\.colorScheme) private var scheme
    
    var body: some View {
        HStack(spacing: CKSpacing.sm) {
            // Action icon
            ZStack {
                Circle()
                    .fill(actionColor.opacity(scheme == .dark ? 0.2 : 0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: actionIcon)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(actionColor)
            }
            
            // Project name & action
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.projectName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(CKColor.textPrimary(scheme))
                    .lineLimit(1)
                
                HStack(spacing: CKSpacing.xs) {
                    Text(actionLabel)
                        .font(.caption)
                        .foregroundColor(actionColor)
                    
                    if let size = entry.fileSize, size > 0 {
                        Text("• \(formatBytes(size))")
                            .font(.caption)
                            .foregroundColor(CKColor.textSecondary(scheme))
                    }
                    
                    if let err = entry.errorMessage {
                        Text("• \(err)")
                            .font(.caption)
                            .foregroundColor(CKColor.dangerRed(scheme))
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            // Result badge
            HStack(spacing: 4) {
                Image(systemName: entry.result == .success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.caption)
                Text(entry.result == .success ? "Thành công".localized : "Thất bại".localized)
                    .font(.caption.weight(.medium))
            }
            .foregroundColor(entry.result == .success ? CKColor.successGreen(scheme) : CKColor.dangerRed(scheme))
            .padding(.horizontal, CKSpacing.sm)
            .padding(.vertical, 3)
            .background((entry.result == .success ? CKColor.successGreen(scheme) : CKColor.dangerRed(scheme)).opacity(scheme == .dark ? 0.15 : 0.1))
            .clipShape(Capsule())
            
            // Timestamp
            Text(formatTimestamp(entry.timestamp))
                .font(.caption)
                .foregroundColor(CKColor.textSecondary(scheme))
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Computed
    private var actionIcon: String {
        switch entry.action {
        case .upload: return CKIcon.upload
        case .download: return CKIcon.download
        case .delete: return CKIcon.delete
        }
    }
    
    private var actionColor: Color {
        switch entry.action {
        case .upload: return CKColor.accentBlue(scheme)
        case .download: return CKColor.successGreen(scheme)
        case .delete: return CKColor.dangerRed(scheme)
        }
    }
    
    private var actionLabel: String {
        switch entry.action {
        case .upload: return "Tải lên".localized
        case .download: return "Tải về".localized
        case .delete: return "Xoá khỏi Mây".localized
        }
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Hôm qua".localized
        } else {
            formatter.dateFormat = "dd/MM"
            return formatter.string(from: date)
        }
    }
}
