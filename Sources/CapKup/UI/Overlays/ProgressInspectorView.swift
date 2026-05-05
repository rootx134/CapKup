import SwiftUI

struct ProgressInspectorView: View {
    @Bindable var syncEngine = SyncEngine.shared
    @Environment(\.colorScheme) private var scheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: CKSpacing.md) {
            Text("Tiến trình Đồng bộ".localized)
                .font(.headline)
                .foregroundColor(CKColor.textPrimary(scheme))
            
            // Active tasks
            let hasActive = syncEngine.activeUploadProject != nil || syncEngine.activeDownloadProject != nil || syncEngine.activeDeleteProject != nil
            
            if hasActive {
                if let project = syncEngine.activeUploadProject {
                    ActiveProgressCard(
                        title: "\("Đang Tải Lên:".localized) \(project.name)",
                        color: CKColor.accentBlue(scheme),
                        iconName: CKIcon.upload,
                        syncEngine: syncEngine
                    )
                }
                
                if let project = syncEngine.activeDownloadProject {
                    ActiveProgressCard(
                        title: "\("Đang Tải Về:".localized) \(project.name)",
                        color: CKColor.successGreen(scheme),
                        iconName: CKIcon.download,
                        syncEngine: syncEngine
                    )
                }
                
                if let project = syncEngine.activeDeleteProject {
                    ActiveProgressCard(
                        title: "\("Đang Xoá:".localized) \(project.name)",
                        color: CKColor.dangerRed(scheme),
                        iconName: CKIcon.delete,
                        syncEngine: syncEngine
                    )
                }
            } else if !syncEngine.uploadQueue.isEmpty || !syncEngine.downloadQueue.isEmpty || !syncEngine.deleteQueue.isEmpty {
                HStack(spacing: CKSpacing.sm) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Đang chuẩn bị...".localized)
                        .font(.subheadline)
                        .foregroundColor(CKColor.textSecondary(scheme))
                }
            } else {
                // Show last completed task or idle state
                if let completedName = syncEngine.lastCompletedName,
                   let completedTime = syncEngine.lastCompletedTime {
                    let isSuccess = syncEngine.lastCompletedSuccess
                    let actionLabel: String = {
                        switch syncEngine.lastCompletedAction {
                        case "upload": return "Tải lên".localized
                        case "download": return "Tải về".localized
                        case "delete": return "Xoá".localized
                        default: return "Đồng bộ".localized
                        }
                    }()
                    
                    VStack(alignment: .leading, spacing: CKSpacing.sm) {
                        HStack(spacing: CKSpacing.xs) {
                            Image(systemName: isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(isSuccess ? CKColor.successGreen(scheme) : CKColor.dangerRed(scheme))
                            Text(isSuccess ? "Hoàn thành".localized : "Thất bại".localized)
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(CKColor.textPrimary(scheme))
                        }
                        
                        Text("\(actionLabel): \(completedName)")
                            .font(.caption)
                            .foregroundColor(CKColor.textSecondary(scheme))
                            .lineLimit(2)
                        
                        Text(formatCompletedTime(completedTime))
                            .font(.caption2)
                            .foregroundColor(CKColor.textSecondary(scheme).opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard(padding: CKSpacing.md)
                    .glowBorder(color: isSuccess ? CKColor.successGreen(scheme) : CKColor.dangerRed(scheme))
                } else {
                    VStack(spacing: CKSpacing.sm) {
                        Image(systemName: CKIcon.synced)
                            .font(.title2)
                            .foregroundColor(CKColor.textSecondary(scheme))
                        Text("Không có tiến trình nào đang chạy.".localized)
                            .font(.subheadline)
                            .foregroundColor(CKColor.textSecondary(scheme))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, CKSpacing.lg)
                }
            }
            
            // Queue section
            if !syncEngine.uploadQueue.isEmpty || !syncEngine.downloadQueue.isEmpty || !syncEngine.deleteQueue.isEmpty {
                Divider()
                    .padding(.vertical, CKSpacing.sm)
                    
                let queueCount = syncEngine.uploadQueue.count + syncEngine.downloadQueue.count + syncEngine.deleteQueue.count
                HStack {
                    Image(systemName: CKIcon.waiting)
                        .foregroundColor(CKColor.accentPurple)
                    Text("\("Đang xếp hàng chờ".localized) (\(queueCount))")
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(CKColor.textPrimary(scheme))
                }
                
                List {
                    ForEach(syncEngine.uploadQueue) { project in
                        QueueItemView(
                            name: project.name,
                            statusText: "Chờ Upload".localized,
                            iconName: CKIcon.upload,
                            color: CKColor.accentBlue(scheme)
                        ) {
                            syncEngine.dequeueProject(project)
                        }
                    }
                    
                    ForEach(syncEngine.downloadQueue) { project in
                        QueueItemView(
                            name: project.name,
                            statusText: "Chờ Tải Về".localized,
                            iconName: CKIcon.download,
                            color: CKColor.successGreen(scheme)
                        ) {
                            syncEngine.dequeueCloudProject(project)
                        }
                    }
                    
                    ForEach(syncEngine.deleteQueue) { project in
                        QueueItemView(
                            name: project.name,
                            statusText: "Chờ Xoá".localized,
                            iconName: CKIcon.delete,
                            color: CKColor.dangerRed(scheme)
                        ) {
                            syncEngine.dequeueCloudProject(project)
                        }
                    }
                }
                .listStyle(.plain)
                .frame(maxHeight: .infinity)
            } else {
                Spacer()
            }
        }
        .padding(CKSpacing.md)
        .frame(minWidth: 260)
    }
    
    private func formatCompletedTime(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return "Vừa xong".localized
        } else if interval < 3600 {
            let mins = Int(interval / 60)
            return "\(mins) " + "phút trước".localized
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        }
    }
}

// MARK: - Active Progress Card
private struct ActiveProgressCard: View {
    let title: String
    let color: Color
    let iconName: String
    var syncEngine: SyncEngine
    @Environment(\.colorScheme) private var scheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: CKSpacing.md) {
            // Header
            HStack(spacing: CKSpacing.xs) {
                Image(systemName: iconName)
                    .foregroundColor(color)
                    .font(.title3)
                Text(title)
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(CKColor.textPrimary(scheme))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    
                Spacer()
                
                // Controls
                if syncEngine.currentProgress > 0 && syncEngine.currentProgress < 1.0 {
                    HStack(spacing: 8) {
                        if syncEngine.isPaused {
                            Button(action: { syncEngine.resumeSync() }) {
                                Image(systemName: "play.fill")
                                    .foregroundColor(CKColor.successGreen(scheme))
                            }
                            .buttonStyle(.plain)
                            .help("Tiếp tục")
                        } else {
                            Button(action: { syncEngine.pauseSync() }) {
                                Image(systemName: "pause.fill")
                                    .foregroundColor(CKColor.warningOrange(scheme))
                            }
                            .buttonStyle(.plain)
                            .help("Tạm dừng")
                        }
                        
                        Button(action: { syncEngine.cancelSync() }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(CKColor.dangerRed(scheme))
                        }
                        .buttonStyle(.plain)
                        .help("Hủy")
                    }
                }
            }
            
            // Mới: Giao diện xếp dọc rộng rãi hơn
            VStack(spacing: CKSpacing.lg) {
                // Vòng tiến độ + ETA căn giữa
                VStack(spacing: CKSpacing.sm) {
                    CircularProgressRing(progress: syncEngine.currentProgress, size: 84)
                    
                    if let eta = syncEngine.estimatedTimeRemaining {
                        Text("Còn lại ~ \(formatETA(eta))")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(CKColor.textSecondary(scheme))
                    } else if syncEngine.isPaused {
                        Text("Đã tạm dừng")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(CKColor.warningOrange(scheme))
                    } else {
                        Text(syncEngine.isSyncing ? "Đang tính..." : "")
                            .font(.system(size: 11))
                            .foregroundColor(CKColor.textSecondary(scheme).opacity(0.5))
                            .frame(height: 14)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, CKSpacing.sm)
                
                Divider()
                    .overlay(CKColor.textSecondary(scheme).opacity(0.1))
                
                // Stepper: chiếm trọn chiều ngang
                PhaseStepper(
                    currentPhase: syncEngine.currentPhase,
                    phases: syncEngine.activeDownloadProject != nil ? SyncPhase.downloadPhases : SyncPhase.uploadPhases
                )
                .padding(.horizontal, 4)
                
                // Biểu đồ tốc độ Sparkline 
                if syncEngine.isSyncing && syncEngine.currentPhase >= .uploading {
                    SpeedSparkline(history: syncEngine.speedHistory)
                        .padding(.top, -CKSpacing.sm)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(padding: CKSpacing.md)
        .glowBorder(color: syncEngine.isPaused ? CKColor.warningOrange(scheme) : color)
    }
    
    private func formatETA(_ time: TimeInterval) -> String {
        if time < 60 { return "\(Int(time))s" }
        let mins = Int(time) / 60
        let secs = Int(time) % 60
        return String(format: "%dm %02ds", mins, secs)
    }
}

// MARK: - Queue Item View
private struct QueueItemView: View {
    let name: String
    let statusText: String
    let iconName: String
    let color: Color
    let onCancel: () -> Void
    @Environment(\.colorScheme) private var scheme
    
    var body: some View {
        HStack {
            Text(name)
                .foregroundColor(CKColor.textPrimary(scheme))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            
            HStack(spacing: CKSpacing.xs) {
                Image(systemName: iconName)
                    .font(.caption2)
                Text(statusText)
                    .font(.caption)
            }
            .foregroundColor(color)
            .padding(.horizontal, CKSpacing.sm)
            .padding(.vertical, 3)
            .background(color.opacity(scheme == .dark ? 0.15 : 0.1))
            .clipShape(RoundedRectangle(cornerRadius: CKRadius.button))
            
            Button(action: onCancel) {
                Image(systemName: CKIcon.cancel)
                    .foregroundColor(CKColor.dangerRed(scheme))
            }
            .buttonStyle(.plain)
            .padding(.leading, CKSpacing.xs)
            .help("Xóa khỏi hàng chờ".localized)
        }
        .padding(.vertical, 2)
    }
}
