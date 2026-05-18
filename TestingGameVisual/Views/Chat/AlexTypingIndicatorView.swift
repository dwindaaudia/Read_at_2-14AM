import SwiftUI

// MARK: - TYPING INDICATOR (Alex)
// White bubble with three pulsing dots — matches Alex text bubbles.

struct AlexTypingIndicatorView: View {
    @State private var pulse = false

    var body: some View {
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
        .onAppear { pulse = true }
    }
}
