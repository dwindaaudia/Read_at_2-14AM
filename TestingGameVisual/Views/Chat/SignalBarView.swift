import SwiftUI

// MARK: - SIGNAL BAR VIEW
// Shown in the toolbar. Represents the denial level as a decaying signal.

struct SignalBarView: View {
    let denialScore: Int

    @State private var glitchAlpha: Double = 1.0

    private var activeBars: Int {
        if denialScore >= 16 { return 1 }
        if denialScore >= 10 { return 2 }
        if denialScore >=  5 { return 3 }
        return 4
    }

    private var barColor: Color {
        if denialScore >= 12 { return .red    }
        if denialScore >=  7 { return .orange }
        if denialScore <= -7 { return .blue   }
        return .green
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 2.5) {
            ForEach(0..<4) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(i < activeBars ? barColor : Color.gray.opacity(0.25))
                    .frame(width: 4, height: CGFloat(5 + i * 5))
                    .opacity(i < activeBars && denialScore >= 16 ? glitchAlpha : 1.0)
            }
        }
        .padding(.trailing, 2)
        .onAppear { startGlitchIfNeeded() }
        .onChange(of: denialScore) { _, _ in startGlitchIfNeeded() }
    }

    private func startGlitchIfNeeded() {
        if denialScore >= 16 {
            withAnimation(.easeInOut(duration: 0.25).repeatForever(autoreverses: true)) {
                glitchAlpha = 0.25
            }
        } else {
            withAnimation(.easeOut(duration: 0.2)) { glitchAlpha = 1.0 }
        }
    }
}
