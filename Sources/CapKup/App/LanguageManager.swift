import SwiftUI

class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    @AppStorage("appLanguage") var currentLanguage: String = "vi"
    
    private let dictionary: [String: [String: String]] = [
        "en": [
            // MARK: - Sidebar / Dashboard
            "Khu vực ổ đĩa": "Storage",
            "Trên Máy": "Local",
            "Trên Mây": "Cloud",
            "Thống kê": "Statistics",
            "Trên Máy:": "Local:",
            "Đã Đồng Bộ:": "Synced:",
            "Trên Mây:": "Cloud:",
            "Dung lượng": "Storage",
            "Cài đặt": "Settings",
            "Chọn một tab ở Sidebar": "Select a tab from the sidebar",
            "Tiến trình Đồng bộ": "Sync Progress",
            
            // MARK: - Settings
            "Giao diện": "Theme",
            "Ngôn ngữ": "Language",
            "Sáng": "Light",
            "Tối": "Dark",
            "Đồng bộ": "Sync",
            "Tự động xóa bản địa sau khi Upload": "Auto-delete local files after upload",
            "Giải phóng ổ đĩa — Sẽ xóa hẳn File trên máy": "Free up disk — Local files will be permanently deleted",
            "Thư mục CapCut": "CapCut Folder",
            "Thay đổi": "Change",
            "Chưa chọn": "Not selected",
            "Thông tin phiên bản": "Version",
            "Đăng xuất": "Logout",
            
            // MARK: - Toolbar
            "Đã chọn": "Selected",
            "Tải lên": "Upload",
            "Xoá": "Delete",
            "Tìm dự án...": "Search projects...",
            "Làm mới Máy": "Refresh Local",
            "Làm mới Mây": "Refresh Cloud",
            "Tải xuống": "Download",
            
            // MARK: - Project List
            "Không tìm thấy Project nào trong thư mục": "No projects found in the folder",
            "Không có Project nào trên Cloud": "No projects on Cloud",
            "Đang tính dung lượng...": "Calculating size...",
            "Đang tính...": "Calculating...",
            
            // MARK: - Sync Status Badges
            "Chưa backup": "Not backed up",
            "Có thay đổi mới": "Has changes",
            "Chờ xếp hàng": "Queued",
            "Đã backup": "Backed up",
            "Tải lên thất bại": "Upload failed",
            
            // MARK: - Context Menu
            "Mở thư mục chứa dự án": "Reveal in Finder",
            "Mở trên Google Drive": "Open in Google Drive",
            "Đổi tên": "Rename",
            "Xoá dự án": "Delete Project",
            "Xoá khỏi Mây": "Delete from Cloud",
            "Tải về": "Download",
            
            // MARK: - Dialogs
            "Tên mới": "New name",
            "Lưu": "Save",
            "Hủy": "Cancel",
            "Xóa vĩnh viễn": "Delete Permanently",
            "Hành động này sẽ xóa VĨNH VIỄN thư mục dự án khỏi máy tính. Không thể hoàn tác!": "This will PERMANENTLY delete the project folder from your computer. This cannot be undone!",
            
            // MARK: - Progress Inspector
            "Đang chuẩn bị...": "Preparing...",
            "Không có tiến trình nào đang chạy.": "No active sync tasks.",
            "Đang xếp hàng chờ": "Queue",
            "Chờ Upload": "Upload Pending",
            "Chờ Tải Về": "Download Pending",
            "Chờ Xoá": "Delete Pending",
            "Xóa khỏi hàng chờ": "Remove from queue",
            
            // MARK: - Upload Progress
            "Đang Tải Lên:": "Uploading:",
            "Đang Tải Về:": "Downloading:",
            "Đang Xoá:": "Deleting:",
            
            // MARK: - Project Info
            "Dự án được tải về": "Downloaded project",
            
            // MARK: - Login
            "Đồng bộ dự án CapCut lên Mây": "Sync CapCut projects to the Cloud",
            "Backup tự động": "Auto Backup",
            "Đồng bộ thông minh": "Smart Sync",
            "Nén & Tối ưu": "Compress & Optimize",
            "Đăng nhập với Google": "Sign in with Google",
            "Xác thực không thành công.": "Authentication failed.",
            
            // MARK: - Setup
            "Chọn Thư mục CapCut Offline": "Select CapCut Offline Folder",
            "Vui lòng chọn ổ đĩa hoặc thư mục chứa các project CapCut để CapKup bắt đầu đồng bộ.": "Please select the drive or folder containing your CapCut projects to start syncing.",
            "Chọn Thư mục CapCut": "Select CapCut Folder",
            "Chọn thư mục Drafts": "Select Drafts Folder",
            
            // MARK: - History Tab
            "Lịch sử": "History",
            "Tất cả": "All",
            "Xoá lịch sử": "Clear History",
            "Chưa có lịch sử đồng bộ": "No sync history yet",
            "Thành công": "Success",
            "Thất bại": "Failed",
            "Hôm qua": "Yesterday",
            "Công cụ": "Tools",
            
            // MARK: - Completion Inspector
            "Hoàn thành": "Completed",
            "Vừa xong": "Just now",
            "phút trước": "min ago",
        ]
    ]
    
    func localized(_ key: String) -> String {
        if currentLanguage == "vi" { return key }
        return dictionary["en"]?[key] ?? key
    }
}

extension String {
    var localized: String {
        LanguageManager.shared.localized(self)
    }
}
