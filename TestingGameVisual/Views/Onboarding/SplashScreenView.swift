import SwiftUI

// MARK: - SPLASH SCREEN — Fake OS Boot Sequence

struct SplashScreenView: View {

    let onComplete: () -> Void

    @State private var visibleLines: [BootLine] = []
    @State private var screenOpacity: Double = 1.0
    @State private var cursorVisible = true

    private let bootScript: [BootLine] = [
        BootLine("SYSTEM BOOTING...",                     color: .white,  delay: 0.30),
        BootLine("OS VERSION: 14.2.1  [BUILD 2019.10.18]", color: .white,  delay: 0.60),
        BootLine("",                                       color: .clear,  delay: 0.80),
        BootLine("CHECKING FILE INTEGRITY...",             color: .white,  delay: 1.10),
        BootLine("WARNING: MEMORY FRAGMENT DETECTED",      color: .red,    delay: 1.60),
        BootLine("RESTORING INCOMPLETE SESSION...",        color: .white,  delay: 2.10),
        BootLine("",                                       color: .clear,  delay: 2.30),
        BootLine("CHAT_LOG: OCT 18 2019  [PARTIAL]",       color: .gray,   delay: 2.70),
        BootLine("ENCRYPTION: FILE_01.enc  [CORRUPTED]",   color: .gray,   delay: 3.10),
        BootLine("",                                       color: .clear,  delay: 3.30),
        BootLine("LOADING: READ_AT_02:14.app",              color: .white,  delay: 3.70),
        BootLine("████████████████████  100%",             color: .white,  delay: 4.30),
        BootLine("",                                       color: .clear,  delay: 4.50),
        BootLine("> CONNECTION ESTABLISHED",               color: .green,  delay: 4.90),
    ]

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 5) {
                ForEach(visibleLines) { line in
                    Text(line.text)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(line.color.opacity(0.85))
                }

                // Blinking cursor while booting
                if visibleLines.count < bootScript.count {
                    Text("█")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                        .opacity(cursorVisible ? 1 : 0)
                        .animation(.easeInOut(duration: 0.5).repeatForever(), value: cursorVisible)
                        .onAppear { cursorVisible.toggle() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 24)
            .padding(.top, 80)
        }
        .opacity(screenOpacity)
        .onAppear { runBootSequence() }
    }

    private func runBootSequence() {
        for line in bootScript {
            DispatchQueue.main.asyncAfter(deadline: .now() + line.delay) {
                withAnimation(.none) {
                    visibleLines.append(line)
                }
                if line.color == .red || line.color == .green {
                    HapticManager.shared.playGlitchHaptic()
                }
            }
        }

        // Fade to MainMenu after last line
        let fadeStart = (bootScript.last?.delay ?? 5.0) + 1.2
        DispatchQueue.main.asyncAfter(deadline: .now() + fadeStart) {
            withAnimation(.easeIn(duration: 0.9)) { screenOpacity = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { onComplete() }
        }
    }
}

private struct BootLine: Identifiable {
    let id = UUID()
    let text: String
    let color: Color
    let delay: TimeInterval

    init(_ text: String, color: Color, delay: TimeInterval) {
        self.text = text; self.color = color; self.delay = delay
    }
}
