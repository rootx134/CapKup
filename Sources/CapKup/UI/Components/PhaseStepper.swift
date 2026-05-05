import SwiftUI

struct PhaseStepper: View {
    let currentPhase: SyncPhase
    let phases: [SyncPhase] // Either uploadPhases or downloadPhases
    
    @Environment(\.colorScheme) private var scheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(phases.enumerated()), id: \.element) { index, phase in
                HStack(alignment: .top, spacing: 12) {
                    // Step Indicator
                    VStack(spacing: 0) {
                        // Icon
                        ZStack {
                            Circle()
                                .fill(backgroundColor(for: phase))
                                .frame(width: 24, height: 24)
                            
                            Image(systemName: iconName(for: phase))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(iconColor(for: phase))
                        }
                        
                        // Connector Line (except for the last item)
                        if index < phases.count - 1 {
                            Rectangle()
                                .fill(lineColor(for: phase, nextPhase: phases[index + 1]))
                                .frame(width: 2, height: 20)
                                .padding(.vertical, 2)
                        }
                    }
                    
                    // Label
                    VStack(alignment: .leading, spacing: 2) {
                        Text(phase.label)
                            .font(.system(size: 13, weight: phase == currentPhase ? .semibold : .medium))
                            .foregroundColor(textColor(for: phase))
                            .padding(.top, 4)
                        
                        if phase == currentPhase {
                            HStack(spacing: 4) {
                                Circle().frame(width: 4, height: 4).foregroundColor(CKColor.accentCyan)
                                Circle().frame(width: 4, height: 4).foregroundColor(CKColor.accentCyan).opacity(0.6)
                                Circle().frame(width: 4, height: 4).foregroundColor(CKColor.accentCyan).opacity(0.3)
                            }
                            .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: currentPhase)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Styling Helpers
    
    private func isCompleted(_ phase: SyncPhase) -> Bool {
        phase < currentPhase
    }
    
    private func isActive(_ phase: SyncPhase) -> Bool {
        phase == currentPhase
    }
    
    private func backgroundColor(for phase: SyncPhase) -> Color {
        if isCompleted(phase) { return CKColor.successGreen(scheme).opacity(0.2) }
        if isActive(phase) { return CKColor.accentCyan.opacity(0.2) }
        return CKColor.cardBackground(scheme)
    }
    
    private func iconColor(for phase: SyncPhase) -> Color {
        if isCompleted(phase) { return CKColor.successGreen(scheme) }
        if isActive(phase) { return CKColor.accentCyan }
        return CKColor.textSecondary(scheme)
    }
    
    private func iconName(for phase: SyncPhase) -> String {
        if isCompleted(phase) { return "checkmark" }
        return phase.iconName
    }
    
    private func textColor(for phase: SyncPhase) -> Color {
        if isActive(phase) { return CKColor.textPrimary(scheme) }
        if isCompleted(phase) { return CKColor.textPrimary(scheme).opacity(0.8) }
        return CKColor.textSecondary(scheme).opacity(0.5)
    }
    
    private func lineColor(for current: SyncPhase, nextPhase: SyncPhase) -> Color {
        if isCompleted(nextPhase) || isActive(nextPhase) {
            return CKColor.successGreen(scheme).opacity(0.5)
        }
        return CKColor.cardBackground(scheme)
    }
}

// #Preview {
//     ZStack {
//         Color(hex: 0x161B22).ignoresSafeArea()
//         PhaseStepper(currentPhase: .uploading, phases: SyncPhase.uploadPhases)
//             .padding()
//     }
// }
