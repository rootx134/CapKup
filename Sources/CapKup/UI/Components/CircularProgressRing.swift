import SwiftUI

struct CircularProgressRing: View {
    let progress: Double // 0.0 to 1.0
    
    // Configurable dimensions
    var lineWidth: CGFloat = 16
    var size: CGFloat = 120
    
    @Environment(\.colorScheme) private var scheme
    
    // Gradient definitions
    private let gradient = LinearGradient(
        colors: [CKColor.accentCyan, CKColor.accentPurple],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(
                    CKColor.cardBackground(scheme),
                    lineWidth: lineWidth
                )
                .frame(width: size, height: size)
            
            // Progress ring
            Circle()
                .trim(from: 0.0, to: min(max(progress, 0.0), 1.0))
                .stroke(
                    gradient,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                
            // Percentage Label
            VStack(spacing: 2) {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: size * 0.25, weight: .bold, design: .rounded))
                    .foregroundColor(CKColor.textPrimary(scheme))
                    .contentTransition(.numericText())
                    .animation(.default, value: progress)
            }
        }
    }
}

// #Preview {
//     ZStack {
//         Color(hex: 0x161B22).ignoresSafeArea()
//         CircularProgressRing(progress: 0.65)
//     }
// }
