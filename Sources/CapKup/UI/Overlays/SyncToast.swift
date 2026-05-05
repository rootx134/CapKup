import SwiftUI

struct SyncToast: View {
    let name: String
    let action: String
    let success: Bool
    
    @Environment(\.colorScheme) private var scheme
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title2)
                .foregroundColor(success ? CKColor.successGreen(scheme) : CKColor.dangerRed(scheme))
                
            VStack(alignment: .leading, spacing: 2) {
                Text(success ? "Đồng bộ thành công" : "Đồng bộ thất bại")
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(CKColor.textPrimary(scheme))
                    
                Text("\(actionLabel(action)): \(name)")
                    .font(.caption)
                    .foregroundColor(CKColor.textSecondary(scheme))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(16)
        .background(CKColor.contentBackground(scheme).opacity(0.95))
        .glassCard(padding: 0)
        .glowBorder(color: success ? CKColor.successGreen(scheme).opacity(0.5) : CKColor.dangerRed(scheme).opacity(0.5))
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 4)
    }
    
    private func actionLabel(_ act: String) -> String {
        switch act.lowercased() {
        case "upload": return "Tải lên"
        case "download": return "Tải về"
        case "delete": return "Xóa"
        default: return act
        }
    }
}

// #Preview {
//     ZStack {
//         Color(hex: 0x161B22).ignoresSafeArea()
//         SyncToast(name: "Demo Project v1.0", action: "upload", success: true)
//     }
// }
