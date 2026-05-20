import SwiftUI

// MARK: - ACT TRANSITION OVERLAY

struct ActTransitionView: View {
    let actNumber: Int
    let actTitle: String
    @Binding var isVisible: Bool

    @State private var blackOpacity: Double = 1.0
    @State private var textOpacity: Double  = 0.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
                .opacity(blackOpacity)

            VStack(spacing: 10) {
                Text("A C T  \(romanNumeral(actNumber))")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.gray)
                    .tracking(8)

                Text(actTitle)
                    .font(.system(size: 30, weight: .black))
                    .foregroundColor(.white)

                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 60, height: 1)
                    .padding(.top, 4)
            }
            .opacity(textOpacity)
        }
        .ignoresSafeArea()
        .onAppear { runTransitionAnimation() }
    }

    private func runTransitionAnimation() {
        withAnimation(.easeIn(duration: 0.35)) { blackOpacity = 1.0 }

        withAnimation(.easeIn(duration: 0.7).delay(0.4)) { textOpacity = 1.0 }
        HapticManager.shared.playTypeHaptic()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
            withAnimation(.easeOut(duration: 0.7)) {
                textOpacity  = 0
                blackOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                isVisible = false
            }
        }
    }

    private func romanNumeral(_ n: Int) -> String {
        switch n { case 1: "I"; case 2: "II"; case 3: "III"; default: "\(n)" }
    }
}
