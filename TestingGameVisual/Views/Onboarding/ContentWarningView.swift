import SwiftUI

// MARK: - CONTENT WARNING

struct ContentWarningView: View {

    let onContinue: () -> Void

    @State private var contentOpacity: Double = 0
    @State private var iconPulse: Bool = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Warning icon
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.red.opacity(0.8))
                    .scaleEffect(iconPulse ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: iconPulse)
                    .onAppear { iconPulse = true }
                    .padding(.bottom, 24)

                Text("CONTENT WARNING")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.red.opacity(0.9))
                    .tracking(3)
                    .padding(.bottom, 20)

                // Warning items
                VStack(alignment: .leading, spacing: 10) {
                    WarningItem(text: "Psychological horror and sustained dread")
                    WarningItem(text: "Themes of loss, grief, and guilt")
                    WarningItem(text: "Disturbing imagery and audio")
                    WarningItem(text: "Flashing lights and visual distortion")
                }
                .padding(.bottom, 32)

                // Atmosphere recommendation
                Text("For maximum immersion:\nPlay alone · at night · with headphones.")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.bottom, 48)

                // CTA button
                Button {
                    HapticManager.shared.playTypeHaptic()
                    withAnimation(.easeIn(duration: 0.4)) { contentOpacity = 0 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { onContinue() }
                } label: {
                    Text("I UNDERSTAND — ENTER")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.red.opacity(0.18))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.red.opacity(0.4), lineWidth: 1)
                        )
                        .cornerRadius(12)
                }
                .padding(.horizontal, 40)

                Spacer()
            }
            .padding(.horizontal, 30)
        }
        .opacity(contentOpacity)
        .onAppear {
            withAnimation(.easeIn(duration: 0.7)) { contentOpacity = 1.0 }
        }
    }
}

private struct WarningItem: View {
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("·").foregroundColor(.red.opacity(0.7))
            Text(text).font(.subheadline).foregroundColor(.white.opacity(0.75))
        }
    }
}
