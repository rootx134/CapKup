import SwiftUI
import Charts

struct SpeedSparkline: View {
    let history: [SpeedSample]
    @Environment(\.colorScheme) private var scheme
    
    // Gradient for the area under the line
    private let areaGradient = LinearGradient(
        colors: [CKColor.accentCyan.opacity(0.3), CKColor.accentPurple.opacity(0.0)],
        startPoint: .top,
        endPoint: .bottom
    )
    
    // Gradient for the line itself
    private let lineGradient = LinearGradient(
        colors: [CKColor.accentCyan, CKColor.accentPurple],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Speed Label
            HStack {
                Text("Tốc độ mạng")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(CKColor.textSecondary(scheme))
                
                Spacer()
                
                if let last = history.last {
                    Text(formatSpeed(last.bytesPerSec))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(CKColor.accentCyan)
                        .contentTransition(.numericText())
                } else {
                    Text("0 B/s")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(CKColor.textSecondary(scheme).opacity(0.5))
                }
            }
            
            // Sparkline Chart
            if history.isEmpty {
                Rectangle()
                    .fill(CKColor.cardBackground(scheme))
                    .frame(height: 48)
                    .cornerRadius(4)
            } else {
                Chart {
                    ForEach(history) { sample in
                        LineMark(
                            x: .value("Time", sample.timestamp),
                            y: .value("Speed", sample.mbps)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(lineGradient)
                        
                        AreaMark(
                            x: .value("Time", sample.timestamp),
                            y: .value("Speed", sample.mbps)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(areaGradient)
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartYScale(domain: 0...(maxSpeed() * 1.2)) // Give 20% headroom
                .frame(height: 48)
                .animation(.linear(duration: 0.5), value: history.count)
            }
        }
        .padding(12)
        .background(Color.clear)
        .cornerRadius(8)
    }
    
    // Formatter
    private func formatSpeed(_ bytesPerSec: Double) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytesPerSec)) + "/s"
    }
    
    private func maxSpeed() -> Double {
        let maxMbps = history.map(\.mbps).max() ?? 1.0
        return max(maxMbps, 0.1) // Avoid 0 scale
    }
}

// #Preview {
//     ZStack {
//         Color(hex: 0x161B22).ignoresSafeArea()
//         let mockData = (0..<60).map { i in
//             SpeedSample(
//                 timestamp: Date().addingTimeInterval(Double(i - 60)),
//                 bytesPerSec: Double.random(in: 1_000_000...5_000_000)
//             )
//         }
//         SpeedSparkline(history: mockData)
//             .padding()
//     }
// }
