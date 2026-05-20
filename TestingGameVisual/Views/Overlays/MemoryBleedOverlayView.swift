import SwiftUI

// MARK: - MEMORY BLEED OVERLAY
// When denialScore ≥ 14, ghost echoes of Alex's previous messages
// occasionally appear translucent on screen, then fade away.
// Non-interactive — just a shadow of memory.

struct MemoryBleedOverlayView: View {
    let denialScore: Int
    let recentAlexMessages: [String]

    @State private var ghostText:    String  = ""
    @State private var ghostOpacity: Double  = 0
    @State private var ghostOffsetY: CGFloat = 0
    @State private var isScheduled:  Bool    = false

    var body: some View {
        ZStack {
            if ghostOpacity > 0 {
                Text(ghostText)
                    .font(.system(size: 17, weight: .ultraLight, design: .monospaced))
                    .foregroundColor(.white.opacity(ghostOpacity * 0.30))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 50)
                    .offset(y: ghostOffsetY)
                    .blur(radius: (1.0 - ghostOpacity) * 5)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .onAppear { scheduleIfNeeded() }
        .onChange(of: denialScore) { _, newVal in
            if newVal >= 14 { scheduleIfNeeded() }
        }
    }

    private func scheduleIfNeeded() {
        guard denialScore >= 14, !isScheduled else { return }
        isScheduled = true
        let delay = Double.random(in: 9...14)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { flash() }
    }

    private func flash() {
        guard denialScore >= 14 else { isScheduled = false; return }
        guard let msg = recentAlexMessages.randomElement() else { isScheduled = false; return }

        ghostText    = msg
        ghostOffsetY = CGFloat.random(in: -120...120)

        withAnimation(.easeIn(duration: 0.6))  { ghostOpacity = 1.0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeOut(duration: 1.4)) { ghostOpacity = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                isScheduled = false
                scheduleIfNeeded()
            }
        }
    }
}
