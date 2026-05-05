import Foundation
import UserNotifications
import AppKit
import OSLog

class NotificationService {
    static let shared = NotificationService()
    
    private init() {}
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                Logger.app.info("Notification permission granted.")
            } else if let err = error {
                Logger.app.error("Notification permission error: \(err.localizedDescription)")
            }
        }
    }
    
    func sendCompletionNotification(projectName: String, action: String, success: Bool) {
        // Chỉ gửi Notification khi App KHÔNG hiển thị ở Foreground
        guard !NSApplication.shared.isActive else { return }
        
        let content = UNMutableNotificationContent()
        
        let actionStr = action == "upload" ? "Tải lên" : (action == "download" ? "Tải về" : "Xoá")
        
        if success {
            content.title = "Đồng bộ thành công"
            content.body = "Đã \(actionStr) dự án: \(projectName)"
            content.sound = UNNotificationSound.default
        } else {
            content.title = "Đồng bộ thất bại"
            content.body = "Có lỗi xảy ra khi \(actionStr): \(projectName)"
            content.sound = UNNotificationSound.defaultCritical
        }
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Fire immediately
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let err = error {
                Logger.app.error("Failed to send notification: \(err.localizedDescription)")
            }
        }
    }
}
