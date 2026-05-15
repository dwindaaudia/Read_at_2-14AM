import SwiftUI

// MARK: - DYNAMIC TYPING INDICATOR
// Alex's typing bubble changes based on psyche/denial level:
// — Low denial   : slow, melancholic, single dot
// — Medium       : normal, occasional brief pauses
// — High         : fast, label text starts to glitch
// — Extreme      : very fast, red, corrupted Ẕ̵a̵l̵g̵o̸ text

struct AlexTypingIndicatorView: View {
    let psycheLevel: PsycheLevel
    let denialScore: Int

    @State private var dotPhase: [Double] = [0, 0, 0]
    @State private var labelText: String  = "Alex is typing..."
    @State private var labelOffset: CGFloat = 0
    @State private var timer: Timer? = nil

    private var speed: Double {
        switch psycheLevel {
        case .low:     return 0.90
        case .medium:  return 0.55
        case .high:    return 0.28
        case .extreme: return 0.12
        }
    }

    private var dotColor: Color {
        switch psycheLevel {
        case .low, .medium: return .white.opacity(0.6)
        case .high:         return .red.opacity(0.85)
        case .extreme:      return .red
        }
    }

    private let labelsByLevel: [PsycheLevel: [String]] = [
        .low:     ["Alex is typing...", "typing...",   "..."],
        .medium:  ["Alex is typing...", "Alex is thinking...", "Still there..."],
        .high:    ["s o m e o n e  i s  t y p i n g", "process...", "please wait..."],
        .extreme: ["Ȃ̸l̷e̵x̶ is near", "SIGNAL CORRUPTED", "D̸̨̬̥͝O̷̧̱̐̾N̸̨̩͝'̶͙̂T̷̨̙̞̉̒ LOOK UP"],
    ]

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            // Dot group
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(dotColor)
                        .frame(width: 7, height: 7)
                        .scaleEffect(1.0 + dotPhase[i] * 0.4)
                        .offset(y: -dotPhase[i] * 4)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18))

            // Dynamic label
            Text(labelText)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
                .offset(x: psycheLevel == .extreme ? labelOffset : 0)
        }
        .padding(.horizontal)
        .onAppear { startAnimations() }
        .onDisappear { timer?.invalidate() }
    }

    private func startAnimations() {
        // Dot bounce animation
        withAnimation(.easeInOut(duration: speed).repeatForever(autoreverses: true)) {
            dotPhase[0] = 1
        }
        withAnimation(.easeInOut(duration: speed).repeatForever(autoreverses: true).delay(speed * 0.33)) {
            dotPhase[1] = 1
        }
        withAnimation(.easeInOut(duration: speed).repeatForever(autoreverses: true).delay(speed * 0.66)) {
            dotPhase[2] = 1
        }

        // Rotate label text on a timer
        let options = labelsByLevel[psycheLevel] ?? ["Alex is typing..."]
        timer = Timer.scheduledTimer(withTimeInterval: speed * 4.5, repeats: true) { _ in
            labelText = options.randomElement() ?? "..."
        }

        // Jittering x-offset for extreme level
        if psycheLevel == .extreme {
            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                labelOffset = CGFloat.random(in: -4...4)
            }
        }
    }
}
