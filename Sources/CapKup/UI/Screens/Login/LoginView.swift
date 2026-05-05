import SwiftUI

struct LoginView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var scheme
    @State private var errorMessage: String? = nil
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0
    
    var body: some View {
        ZStack {
            // Adaptive gradient background
            CKColor.loginGradient(scheme)
                .ignoresSafeArea()
            
            VStack(spacing: CKSpacing.lg) {
                Spacer()
                
                // Logo with glow animation
                ZStack {
                    // Glow circle behind logo
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [CKColor.accentCyan.opacity(scheme == .dark ? 0.3 : 0.15), .clear],
                                center: .center,
                                startRadius: 10,
                                endRadius: 80
                            )
                        )
                        .frame(width: 160, height: 160)
                    
                    // Cloud icon
                    ZStack {
                        Image(systemName: CKIcon.logo)
                            .font(.system(size: 56, weight: .medium))
                            .foregroundStyle(CKColor.logoGradient)
                        
                        Image(systemName: CKIcon.logoArrow)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(CKColor.textPrimary(scheme))
                            .offset(y: -2)
                    }
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
                .onAppear {
                    withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                        logoScale = 1.0
                        logoOpacity = 1.0
                    }
                }
                
                // App Name
                Text("CapKup")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(CKColor.textPrimary(scheme))
                
                // Subtitle
                Text("Đồng bộ dự án CapCut lên Mây".localized)
                    .font(.title3)
                    .foregroundColor(CKColor.textSecondary(scheme))
                
                // Feature pills
                HStack(spacing: CKSpacing.sm) {
                    FeaturePill(iconName: CKIcon.synced, text: "Backup tự động".localized)
                    FeaturePill(iconName: CKIcon.changed, text: "Đồng bộ thông minh".localized)
                    FeaturePill(iconName: "shippingbox.fill", text: "Nén & Tối ưu".localized)
                }
                .padding(.top, CKSpacing.sm)
                
                // Error message
                if let error = errorMessage {
                    HStack(spacing: CKSpacing.xs) {
                        Image(systemName: CKIcon.failed)
                            .foregroundColor(CKColor.dangerRed(scheme))
                        Text(error)
                            .foregroundColor(CKColor.dangerRed(scheme))
                    }
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, CKSpacing.xl)
                }
                
                // Login button
                Button(action: performLogin) {
                    HStack(spacing: CKSpacing.sm) {
                        Image(systemName: CKIcon.login)
                            .font(.title3)
                        Text("Đăng nhập với Google".localized)
                            .font(.headline)
                    }
                    .padding(.horizontal, CKSpacing.xl)
                    .padding(.vertical, CKSpacing.md)
                    .frame(maxWidth: 320)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(CKColor.accentBlue(scheme))
                .clipShape(RoundedRectangle(cornerRadius: CKRadius.button))
                .padding(.top, CKSpacing.sm)
                
                Spacer()
                
                // Version
                Text("v2.1.0")
                    .font(.caption2)
                    .foregroundColor(CKColor.textSecondary(scheme).opacity(0.5))
                    .padding(.bottom, CKSpacing.md)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func performLogin() {
        self.errorMessage = nil
        Task {
            do {
                let success = try await GoogleDriveService.shared.authenticate()
                if success {
                    await MainActor.run {
                        withAnimation { appState.loginSuccess() }
                    }
                } else {
                    self.errorMessage = "Xác thực không thành công."
                }
            } catch {
                let nsError = error as NSError
                // Silently ignore user cancellation (ASWebAuthenticationSession error 1)
                if nsError.domain == "com.apple.AuthenticationServices.WebAuthenticationSession"
                    && nsError.code == 1 {
                    // User cancelled login — do nothing
                    return
                }
                self.errorMessage = error.localizedDescription
            }
        }
    }
}
