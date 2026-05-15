import SwiftUI

// MARK: - VOICE NOTE PLAYER

struct VoiceNotePlayerBubble: View {
    let filename: String
    let isFromMe: Bool
    
    @StateObject private var controller = VoiceNoteAudioController()
    @State private var barHeights: [CGFloat] = (0..<28).map { _ in CGFloat.random(in: 6...22) }
    
    var body: some View {
        HStack(spacing: 10) {
            Button {
                controller.toggle(filename: filename)
                HapticManager.shared.playTypeHaptic()
            } label: {
                Image(systemName: controller.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(isFromMe ? .white : .red)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 2.5) {
                    ForEach(barHeights.indices, id: \.self) { i in
                        let fraction = Double(i) / Double(barHeights.count)
                        let isPast = fraction <= controller.progress
                        Capsule()
                            .fill(waveColor(isPast: isPast))
                            .frame(width: 3, height: barHeights[i])
                            .scaleEffect(
                                controller.isPlaying && isPast ? 1.0 : 0.6,
                                anchor: .bottom
                            )
                            .animation(
                                controller.isPlaying
                                ? .easeInOut(duration: 0.15).delay(Double(i) * 0.01)
                                : .easeOut(duration: 0.2),
                                value: controller.isPlaying
                            )
                    }
                }
                .frame(height: 28)
                
                HStack {
                    Text(formattedTime(controller.duration * controller.progress))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(isFromMe ? .white.opacity(0.7) : .gray)
                    Spacer()
                    Text(formattedTime(controller.duration))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(isFromMe ? .white.opacity(0.5) : .gray.opacity(0.6))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(isFromMe ? Color.red : Color(UIColor.secondarySystemBackground))
        .clipShape(ChatBubbleShape(isFromMe: isFromMe))
        .frame(maxWidth: 260)
    }
    
    private func waveColor(isPast: Bool) -> Color {
        if isPast {
            return isFromMe ? .white.opacity(0.9) : .red
        } else {
            return isFromMe ? .white.opacity(0.3) : Color.gray.opacity(0.35)
        }
    }
    
    private func formattedTime(_ seconds: Double) -> String {
        let s = Int(seconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
