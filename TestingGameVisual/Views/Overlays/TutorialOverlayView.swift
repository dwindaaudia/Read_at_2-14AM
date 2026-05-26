import SwiftUI

// MARK: - TUTORIAL OVERLAY
// Shown until the player makes their first chat choice (pre-game / 2:13–2:14 intro).

struct TutorialOverlayView: View {
    @Binding var isVisible: Bool
    @State private var pulse = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.88)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 28) {

                // Header
                VStack(spacing: 6) {
                    Text("INCOMING TRANSMISSION")
                        .font(.helvetica(10))
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)
                        .tracking(3)

                    Text("Your words\nshape his world.")
                        .font(.helvetica(26))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                    
                    Text("• Turn your volume up — sound here is evidence, not atmosphere.\n• Your words shape what happens. No wrong answers, but every choice leaves a trace.\n• Someone's been trying to reach you every night at 2:14 AM.")
                        .font(.helvetica(14))
                        .foregroundColor(.white)
                    Text("Pay attention.")
                        .font(.helvetica(14))
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.top, 5)
                }

                // Tap to dismiss cue
                Text("Tap anywhere to begin")
                    .font(.helvetica(12))
                    .foregroundColor(.gray.opacity(0.55))
                    .opacity(pulse ? 1.0 : 0.4)
                    .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: pulse)
                    .onAppear { pulse = true }
            }
            .padding(28)
            .background(Color.white.opacity(0.04))
            .cornerRadius(22)
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .padding(28)
            .onTapGesture { dismiss() }
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.35)) { isVisible = false }
        HapticManager.shared.playTypeHaptic()
    }
}

private struct TutorialChoiceRow: View {
    let color: Color
    let label: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(color)
                .frame(width: 56)
                .padding(.vertical, 6)
                .background(color.opacity(0.18), in: Capsule())
                .overlay(Capsule().stroke(color.opacity(0.4), lineWidth: 1))
                .padding(.top, 1)

            Text(description)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.75))
                .lineSpacing(3)

            Spacer()
        }
    }
}
