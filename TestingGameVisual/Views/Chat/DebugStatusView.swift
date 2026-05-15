import SwiftUI

// MARK: - Debug Status View

struct DebugStatusView: View {
    let denialScore: Int
    let currentAct: Int
    let currentScene: String
    let modelStatus: String
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                DebugStatChip(label: "Denial", value: "\(denialScore)", tint: .red)
                DebugStatChip(label: "Act",    value: "\(currentAct)", tint: .blue)
                DebugStatChip(label: "Scene",  value: currentScene,    tint: .orange)
                DebugStatChip(label: "Mode",   value: modelStatus,     tint: .purple)
            }
            .padding(12)
        }
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.14), lineWidth: 1))
    }
}

private struct DebugStatChip: View {
    let label: String
    let value: String
    let tint: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption2).foregroundColor(.white.opacity(0.65))
            Text(value).font(.caption.weight(.semibold)).foregroundColor(.white)
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(tint.opacity(0.18), in: Capsule())
        .overlay(Capsule().stroke(tint.opacity(0.45), lineWidth: 1))
    }
}
