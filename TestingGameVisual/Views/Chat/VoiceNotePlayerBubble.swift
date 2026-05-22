import SwiftUI

// MARK: - VOICE NOTE PLAYER

struct VoiceNotePlayerBubble: View {
    let filename: String
    let isFromMe: Bool
    var autoPlay: Bool = false

    @StateObject private var controller = VoiceNoteAudioController()
    @State private var barHeights: [CGFloat] = (0..<28).map { _ in CGFloat.random(in: 6...22) }
    @State private var didAutoPlay = false

    var body: some View {
        HStack(spacing: 10) {
            Button {
                controller.toggle(filename: filename)
                HapticManager.shared.playTypeHaptic()
            } label: {
                Image(systemName: controller.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
            }
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
            
            // vn duration
            Text(formattedTime(controller.progress == 0 ? controller.duration : (controller.duration * controller.progress)))
                .font(.helvetica(10))
                .foregroundColor(.white.opacity(0.85))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(isFromMe ? Color(red: 0.545, green: 0, blue: 0) : Color(red: 0.216, green: 0.2, blue: 0.2))
        .clipShape(Rectangle())
        .frame(maxWidth: 260, alignment: isFromMe ? .trailing : .leading)
        .fixedSize(horizontal: true, vertical: false)
        .onAppear {
            guard autoPlay, !didAutoPlay, !controller.isPlaying else { return }
            didAutoPlay = true
            controller.toggle(filename: filename)
        }
    }

    private func waveColor(isPast: Bool) -> Color {
        if isPast {
            return isFromMe ? .white.opacity(0.95) : .white.opacity(0.85)
        } else {
            return isFromMe ? .white.opacity(0.35) : .white.opacity(0.28)
        }
    }

    private func formattedTime(_ seconds: Double) -> String {
        let s = Int(seconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
