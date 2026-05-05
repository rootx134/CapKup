# 🚀 CapKup
**Phần mềm đồng bộ tự động, nén và bảo vệ Dự Án CapCut PC lên Google Drive**

![CapKup Dashboard](https://raw.githubusercontent.com/username/capkup/main/docs/dashboard.png)

CapKup (trước đây là CapKupSync) là ứng dụng macOS Native chuyên biệt dành cho giới sáng tạo nội dung, giúp tự động upload dự án của phần mềm edit video CapCut (PC) lên đám mây Google Drive hoàn toàn bảo mật và giải phóng thiết bị gốc.

## 🌟 Tính Năng Nổi Bật

- **🔄 Đồng Bộ Thông Minh (Smart Sync):** Tự động phân tích tệp thay đổi, không upload lại các file video/audio đã có trên Google Drive để tiết kiệm thời gian.
- **📦 Đóng Gói Tối Ưu:** Nén toàn bộ cấu trúc dự án (Media, Cache, Draft) thành một file archive duy nhất.
- **🔐 Bảo Mật Tuyệt Đối (AES-256-GCM):** Tệp tin được mã hóa hai chiều bằng công nghệ AES chuẩn quân đội (Military-grade AES-256-GCM). Chỉ có CapKup thông qua tài khoản Google của chũ dự án mới có thể giải mã và mở được file này trên máy trạm khác.
- **🚀 Quản Lý Bộ Nhớ RAM Tối Ưu:** Hỗ trợ Streaming Encryption chia nhỏ xử lý theo Block (2MB per Block), cho phép nén và up các dự án nặng vài GB mà không bị "ngập RAM".
- **🧹 Dọn Dẹp Không Gian (Auto Cleanup):** Hỗ trợ tính năng Xóa bản địa sau khi đã Upload Mây thành công, trả lại hàng trăm GB ổ đĩa cho máy tính.
- **🎨 Giao Diện Tuyệt Đẹp:** Hỗ trợ Native Dark Mode cho macOS, phong cách Glassmorphism thanh lịch. Lịch sử đồng bộ chi tiết.

## 💿 Yêu cầu hệ thống

- macOS 14.0 (Sonoma) trở lên
- Có sẵn thư mục Draft của CapCut (PC) (vd: `com.lveditor.draft`)

## 🛠 Cách Cài Đặt

1. Tải bản build `.dmg` mới nhất tại mục [Releases](https://github.com/username/capkup/releases).
2. Kéo thả file `CapKup.app` vào thư mục **Applications**.
3. Mở phần mềm và ủy quyền (Login) với Google Drive.
4. **Cài Đặt:** Thư mục CapCut của bạn sẽ được tự động nhận dạng.

## 🚀 Tự Build từ Mã Nguồn (Dành cho Developer)

```bash
# Clone repository
git clone https://github.com/username/capkup.git
cd capkup

# Chạy script build ra file .app (có sẵn trong Repo)
chmod +x QuickUpdateCapKup.command
./QuickUpdateCapKup.command
```
*(Bạn cần thay đổi OAuth Config của Google Cloud Platform trong `OAuthConfig.plist` để sử dụng Backend của riêng mình).*

## 📄 Cấu Trúc Khóa Mã Hoá (Dành cho Dev đam mê Crypto)

File dự án sau khi kéo lên đám mây mang đuôi `.capkup`. Đây không phải là file giải nén được bằng Winrar. Cấu trúc của khối Header của file như sau:

```
┌──────────────────────────────────────┐
│ "CAPKUP"          (6 bytes magic)    │ ← File bắt đầu bằng chữ ký
│ 0x03              (1 byte version)   │ ← Phiên bản (V3 Streaming)
│ 0x01              (1 byte flags)     │ ← encrypted = true
│ Random Salt       (32 bytes)         │ ← Cho quá trình Key Derivation
│ ═══════════════════════════════════  │
│ [CHUNK LENGTH]    (4 bytes)          │ ← Chunk 2MB
│ [NONCE]           (12 bytes)         │ ← AES-GCM IV
│ [CIPHERTEXT]      (2MB DATA)         │ ← File gốc bị mã hóa
│ [AUTH TAG]        (16 bytes)         │ ← Chống thay đổi dữ liệu
└──────────────────────────────────────┘
```

CapKup dùng Google Refresh Token để mix `HKDF(SHA-256)` cùng Random Salt tạo ra mã khóa (Key). Do đó, file backup sinh ra mang bộ gene gắn liền với tài khoản Google. **Chỉ khi đăng nhập chính tài khoản Google Drive đó** mới giải nén được.

## 🫶 Ủng Hộ & Giấy Phép
Dự án được xây dựng với mục tiêu giúp cộng đồng giải quyết triệt để nỗi lo thiếu dung lượng ổ đĩa. Mọi đóng góp (Pull Request, Issue) đều được chào đón!

*Giấy phép: MIT License*
