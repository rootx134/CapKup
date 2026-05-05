# Kế hoạch Triển khai Tính năng Mới (v2.2.0)

Bản cập nhật này sẽ bổ sung 3 chức năng chính theo yêu cầu của bạn, nhằm mang lại sự linh hoạt và mở rộng khả năng khai thác dữ liệu qua Google Drive.

## Mức độ quan trọng & Thay đổi cốt lõi

> [!WARNING]
> Tính năng "Đăng nhập nhiều tài khoản Google Drive" đòi hỏi thay đổi lớn về Kiến trúc Xác thực (Auth Architecture) của ứng dụng. `GoogleDriveService` hiện tại đang được thiết kế dạng *Singleton* quản lý 1 phiên đăng nhập duy nhất. Việc hỗ trợ nhiều phiên cùng lúc sẽ yêu cầu refactor phần lưu trữ Token (Keychain) và logic Upload/Download.

---

## Danh sách Công việc Đề xuất (Proposed Changes)

### 1. Tự động Load Đồng bộ Danh sách khi mở App
- **Vấn đề hiện tại**: Cần phải bấm "Làm mới" hoặc tab phải `.isEmpty` mới gọi hàm scan file.
- **Giải pháp**: 
  - Khởi chạy tiến trình `scanProjects` và `loadCloudProjects` ngay khi `DashboardView` hiển thị (`.onAppear`), bất kể danh sách có rỗng hay không.
  - Gắn cờ logic chặn Spam (chỉ tự động refresh 1 lần duy nhất lúc khởi động app, sau đó tuỳ người dùng làm mới thủ công để tránh tốn API Quota).

#### [MODIFY] `DashboardView.swift`
#### [MODIFY] `LocalProjectListView.swift`
#### [MODIFY] `CloudProjectListView.swift`

### 2. Tuỳ chọn Thư mục Giải nén (Download Directory)
- **Vấn đề hiện tại**: Ứng dụng luôn tải dự án đám mây về chung thư mục CapCut mặc định của máy (`localRootURL`).
- **Giải pháp**:
  - Bổ sung một biến tuỳ chọn `@AppStorage("customDownloadPath")`.
  - Trong màn hình **Settings**, thêm một nút `Chọn thư mục...` bên cạnh danh mục "Thư mục Tải về". Mặc định vẫn sẽ là Thư mục Dự án CapCut.
  - Cập nhật luồng `SyncEngine+Cloud.swift`: Ở Phase giải nén (`extracting`), hệ thống sẽ check biến cấu hình này. Nếu có thư mục Custom, sẽ giải nén trực tiếp vào đó thay vì thư mục CapCut Gốc.

#### [MODIFY] `SettingsView.swift`
#### [MODIFY] `SyncEngine+Cloud.swift`

### 3. Đăng nhập đa Tài khoản Google Drive & Cộng dồn Dung lượng
- **Vấn đề hiện tại**: Chỉ 1 tài khoản được lưu Token lên `KeychainService` mỗi thời điểm.
- **Giải pháp**:
  - **Mô hình Dữ liệu (Models)**: Tạo model `DriveAccount` để quản lý nhiều ID tài khoản, mỗi ID ánh xạ ra 1 cặp Token (Access/Refresh).
  - **KeychainService**: Mở rộng để lưu token theo ID dạng `GoogleDriveAccessToken_<ID>`.
  - **Quản lý Tài khoản (UI)**: Trong **SettingsView**, hiển thị danh sách các tài khoản đang liên kết, cùng mức dung lượng của từng cái và tổng dung lượng.
  - **Logic Ghép nối (Pooling)**:
    - Khi **Tính dung lượng**: Tính tổng Max Storage và tổng Usage của tất cả Account đang active.
    - Khi **Tải danh sách**: Gửi Get API tới *tất cả* các Account để gộp các Project Cloud lại.
    - Khi **Tải lên**: Thuật toán chọn tài khoản nào có mức *Dung lượng trống* nhiều nhất để đẩy Project vào, từ đó tận dụng được tổng Pool lưu trữ.

> [!IMPORTANT]
> **Giới hạn API (Rate Limit)**: Việc kết nối 3-4 tài khoản có thể đồng nghĩa với việc gửi nhiều Request API cùng lúc tới Google lúc khởi động. App sẽ bổ sung async logic để gọi đồng thời không bị khoá luồng (Block/Delay).
> 
> **Câu hỏi Mở**: Nếu đăng nhập nhiều tài khoản, khi một dự án bị Upload lên, hệ thống sẽ tự động bốc 1 tài khoản dư dả nhất để chứa dự án đó. Bạn có đồng ý với logic tự động phân bổ thông minh (Smart Router) này và gộp chung tổng Limit, không cần bắt User phải chọn thủ công Account để upload không?

#### [MODIFY] `KeychainService.swift`
#### [MODIFY] `GoogleDriveService.swift`
#### [MODIFY] `SettingsView.swift`

---

## Xác minh & Kiểm thử (Verification Plan)
1. Xoá Keychain cũ, thực hiện thử đăng nhập 2 tài khoản Google khác nhau.
2. Kiểm tra tổng số dung lượng khả dụng trên Dashboard hiển thị có chính xác với cộng dồn không.
3. Thử tải 1 Project nhỏ về "Màn hình Desktop" xem có giải nén thành công không thay vì chui vào thư mục draft mặc định của CapCut.
4. Tắt App, mở lại và quan sát quá trình Loading tự động hiển thị Progress Indicator của việc đọc file ở hai bên tab.
