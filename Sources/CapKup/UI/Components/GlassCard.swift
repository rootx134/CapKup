import SwiftUI

// MARK: - Glass Card ViewModifier
// Adaptive card style: dark glassmorphism or light elevated card.

struct GlassCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    var padding: CGFloat = CKSpacing.md
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(CKColor.cardBackground(scheme))
            .clipShape(RoundedRectangle(cornerRadius: CKRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: CKRadius.card)
                    .stroke(CKColor.cardBorder(scheme), lineWidth: scheme == .dark ? 1 : 0.5)
            )
            .shadow(
                color: scheme == .dark ? .clear : .black.opacity(0.04),
                radius: 6, x: 0, y: 2
            )
    }
}

extension View {
    func glassCard(padding: CGFloat = CKSpacing.md) -> some View {
        modifier(GlassCardModifier(padding: padding))
    }
}

// MARK: - Toolbar Style ViewModifier
struct CKToolbarModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    
    func body(content: Content) -> some View {
        content
            .padding(CKSpacing.md)
            .background(CKColor.toolbarBackground(scheme))
    }
}

extension View {
    func ckToolbar() -> some View {
        modifier(CKToolbarModifier())
    }
}

// MARK: - Glow Border Modifier (for active sync cards)
struct GlowBorderModifier: ViewModifier {
    let color: Color
    @Environment(\.colorScheme) private var scheme
    
    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: CKRadius.card)
                    .stroke(color.opacity(scheme == .dark ? 0.5 : 0.35), lineWidth: 1.5)
            )
            .shadow(
                color: color.opacity(scheme == .dark ? 0.25 : 0.12),
                radius: 10, x: 0, y: 0
            )
    }
}

extension View {
    func glowBorder(color: Color) -> some View {
        modifier(GlowBorderModifier(color: color))
    }
}

// MARK: - Feature Pill (for Login screen)
struct FeaturePill: View {
    let iconName: String
    let text: String
    @Environment(\.colorScheme) private var scheme
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.caption)
                .foregroundColor(CKColor.accentBlue(scheme))
            Text(text)
                .font(.caption)
                .foregroundColor(CKColor.textSecondary(scheme))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(CKColor.cardBackground(scheme))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(CKColor.cardBorder(scheme), lineWidth: scheme == .dark ? 1 : 0.5)
        )
    }
}
