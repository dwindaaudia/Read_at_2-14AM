import SwiftUI

// MARK: - TYPING INDICATOR (Alex)
// White bubble with three pulsing dots — matches Alex text bubbles.

struct AlexTypingIndicatorView: View {
    @State private var pulse = false
    @State private var isBubbleVisible = true

    var body: some View {
        Group {
            if isBubbleVisible {
                typingBubble
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeInOut(duration: 0.28), value: isBubbleVisible)
        .onAppear { pulse = true }
        .task { await runHesitationLoop() }
    }

    private var typingBubble: some View {
        HStack(alignment: .top, spacing: 0) {
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.black.opacity(0.42))
                        .frame(width: 6, height: 6)
                        .scaleEffect(pulse ? 1.12 : 0.88)
                        .opacity(pulse ? 1.0 : 0.38)
                        .animation(
                            .easeInOut(duration: 0.45)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.16),
                            value: pulse
                        )
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 13)
            .background(
                Rectangle()
                    .fill(Color.white)
            )
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    @MainActor
    private func runHesitationLoop() async {
        isBubbleVisible = true
        try? await Task.sleep(for: .seconds(6))

        while !Task.isCancelled {
            withAnimation(.easeInOut(duration: 0.28)) {
                isBubbleVisible = false
            }
            try? await Task.sleep(for: .milliseconds(Int.random(in: 750...1_350)))
            if Task.isCancelled { return }

            withAnimation(.easeInOut(duration: 0.28)) {
                isBubbleVisible = true
            }
            try? await Task.sleep(for: .milliseconds(Int.random(in: 1_800...3_600)))
        }
    }
}
