# Ghi Chú Phát Triển Tương Lai: Tính Năng Xóa External Media Gốc (Cảnh Báo Nguy Hiểm)

**Ngày ghi nhận:** 07/04/2026
**Trạng thái:** Tạm hoãn (Đưa vào backlog cho các phiên bản tương lai)
**Mục tiêu:** Tự động dò tìm đường dẫn và xóa vĩnh viễn các file video/ảnh gốc (external media) nằm rải rác ngoài thư mục cấu hình CapCut (như Downloads, Ổ cứng rời, Desktop...) sau khi dự án đồng bộ lên Drive thành công.

---

## Yêu Cầu Chức Năng (Requirements)
1. Cần có 2 lớp bảo vệ (Double layer warning) vì lệnh này sẽ xóa file vĩnh viễn không khôi phục được từ hệ điều hành.
2. Thiết lập trên màn hình Cài Đặt (Settings) kèm Cảnh báo Xác nhận khi gạt Bật/Tắt công tắc.
3. Khi chức năng ở trạng thái BẬT, mọi lệnh kích hoạt `Upload` (cho dự án đơn lẻ hoặc nhiều dự án) đều phải có một Cảnh báo Xác nhận lần 2 trước khi thực sự tải lên.
4. Chỉ tiến hành lệnh `FileManager.removeItem(...)` đối với external file sau khi Resumable HTTP trả về báo Upload thành công.

---

## Đề Xuất Giải Pháp Mã Nguồn (Thiết Kế)

### 1. Thêm Cấu Hình `UserDefaults`
Sử dụng cờ: `deleteExternalMediaAfterUpload`

### 2. Sửa UI tại `SettingsView.swift`
Thêm một `Toggle` gắn liền với `.alert()` nếu có sự thay đổi Binding sang giá trị `true`.

### 3. Sửa UI tại `LocalProjectListView.swift` (Và các Component)
Với mọi Button gọi `SyncEngine.shared.enqueueProjects(...)`:
Bọc vào hàm trung gian check `UserDefaults`. Nếu `true`, show một `.confirmationDialog` hoặc `.alert` đỏ: *"CẢNH BÁO: Tùy chọn Xóa Media Nguyên Bản Đang Bật! Quá trình upload thành công sẽ phá hủy các file gốc!"*.

### 4. Bổ Sung Logic Xóa vào `SyncEngine.swift`
Tại hàm `func syncProject()`, tại Bước 5 (Tải lên Drive):
Sau đoạn `let success = try await GoogleDriveService.shared.uploadLargeFile(...)`:

```swift
// Thực thi xóa nếu cờ báo đúng và upload đã hoàn thiện 100%
if success && UserDefaults.standard.bool(forKey: "deleteExternalMediaAfterUpload") {
    for externalPath in externalMediaPaths {
        try? FileManager.default.removeItem(atPath: externalPath)
    }
}
```

> **Lưu ý Dành Cho Lập Trình Viên:** Hãy luôn cực kì cẩn trọng test chức năng này bằng các thư mục file copy, do `FileManager.removeItem` thao tác ở mức thấp sẽ tiễu trừ file không qua Thùng rác (Trash) của macOS.
