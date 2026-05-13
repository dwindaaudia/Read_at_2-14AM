import SwiftUI

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: SPLASH SCREEN — Fake OS Boot Sequence
// MARK: ─────────────────────────────────────────────────────────────────────

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


// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: MAIN MENU
// MARK: ─────────────────────────────────────────────────────────────────────

struct MainMenuView: View {

    let onNewGame: () -> Void
    let onContinue: () -> Void

    @State private var titleOpacity: Double   = 0
    @State private var buttonsOpacity: Double = 0
    @State private var glitchOffsetX: CGFloat = 0
    @State private var showSettings  = false
    @State private var showCredits   = false
    @State private var showHowToPlay = false
    @State private var showAchievements = false

    // Random glitch timer
    @State private var glitchTimer: Timer?

    var body: some View {
        ZStack {
            // ── Background ─────────────────────────────────────────────────
            Image("ls_wallpaper")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
                .opacity(0.5)

            // Subtle scanlines overlay
            VStack(spacing: 0) {
                ForEach(0..<50, id: \.self) { i in
                    Color.white
                        .opacity(i % 4 == 0 ? 0.025 : 0)
                        .frame(height: 2)
                    Color.clear.frame(height: 14)
                }
            }
            .allowsHitTesting(false)

            // ── Content ────────────────────────────────────────────────────
            VStack(spacing: 0) {
                HStack {
                    Text("Friday 8")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.trailing, 18)
                    
                    // Glitch Title
                    ZStack {
                        // Red chromatic ghost
                        Text("2:14")
                            .font(.system(size: 56, weight: .black))
                            .foregroundColor(.red.opacity(0.55))
                            .offset(x: glitchOffsetX + 3, y: 2)
                        
                        // Cyan chromatic ghost
                        Text("2:14")
                            .font(.system(size: 56, weight: .black))
                            .foregroundColor(.cyan.opacity(0.35))
                            .offset(x: -glitchOffsetX - 2, y: -2)
                        
                        // Main white title
                        Text("2:14")
                            .font(.system(size: 56, weight: .black))
                            .foregroundColor(.white)
                    }
                    .opacity(titleOpacity)
                    
                    Text("Chapter 1")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.leading, 18)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 100)
                
                Spacer()
                
                // ── Scroll View for Alex Notifications ───────────────────
                VStack {
                    HStack {
                        Text("Notifications")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text("Clear All")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 10) {
                            // Contoh pemanggilan manual
                            AlexNotificationCard(message: "Are you awake?", time: "02:14 AM")
                            
                            AlexNotificationCard(message: "I saw it behind you.", time: "02:14 AM")
                            
                            AlexNotificationCard(message: "Run.", time: "02:14 AM")
                            
                            // Atau jika menggunakan data array:
                            /*
                             ForEach(notifications) { notification in
                             AlexNotificationCard(message: notification.text, time: notification.time)
                             }
                             */
                        }
                        .padding(.top, 20)
                    }
                    .frame(maxHeight: 350)
                    .mask(
                        LinearGradient(gradient: Gradient(colors: [.clear, .black, .black, .clear]), startPoint: .top, endPoint: .bottom)
                    )
                }
                
                Text("Click the Notification to Play the Game")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.bottom, 50)

                // ── Menu Buttons ───────────────────────────────────────────
                HStack() {
                    
                    // 1. SETTINGS
                    Button(action: {
                        HapticManager.shared.playTypeHaptic()
                        showSettings = true
                    }) {
                        VStack(spacing: 10) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                            Text("SETTINGS")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 40)
                    
                    // 2. CHAT
                    // Logika Tukar Tombol: NEW CHAT vs CONTINUE CHAT
                        if GameSaveManager.shared.hasSave {
                            // Tampilkan ini jika SUDAH PERNAH main
                            Button(action: {
                                HapticManager.shared.playTypeHaptic()
                                withAnimation(.easeIn(duration: 0.3)) { buttonsOpacity = 0 }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { onContinue() }
                            }) {
                                VStack(spacing: 10) {
                                    Image(systemName: "message.fill")
                                        .font(.system(size: 30))
                                        .foregroundColor(.white) // Beri warna beda agar pemain sadar ini save-an
                                    Text("CHAT")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                        } else {
                            // Tampilkan ini jika PLAYER BARU
                            Button(action: {
                                HapticManager.shared.playTypeHaptic()
                                withAnimation(.easeIn(duration: 0.3)) { buttonsOpacity = 0 }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { onNewGame() }
                            }) {
                                VStack(spacing: 10) {
                                    Image(systemName: "message.badge.fill") // Ikon berbeda sedikit untuk "New"
                                        .font(.system(size: 30))
                                        .foregroundColor(.white)
                                    Text("CHAT")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                    
                    // 3. EVIDENCES FILE
                    Button(action: {
                        EvidenceBoardButton()
                    }) {
                        VStack(spacing: 10) {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                            Text("FILES")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 40)
                }
//                .opacity(buttonsOpacity)
                .tint(Color.red.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .bottom)
                .padding(.bottom, 70)
            }
        }
        .onAppear {
            withAnimation(.easeIn(duration: 1.4))               { titleOpacity   = 1.0 }
            withAnimation(.easeIn(duration: 1.0).delay(0.9))   { buttonsOpacity = 1.0 }
            startGlitchLoop()
        }
        .onDisappear { glitchTimer?.invalidate() }
        .sheet(isPresented: $showSettings)  { SettingsView() }
    }

    // Irregular glitch bursts on the title
    private func startGlitchLoop() {
        scheduleNextGlitch()
    }

    private func scheduleNextGlitch() {
        let waitTime = Double.random(in: 3.5...8.0)
        glitchTimer = Timer.scheduledTimer(withTimeInterval: waitTime, repeats: false) { _ in
            runGlitchBurst()
            scheduleNextGlitch()
        }
    }

    private func runGlitchBurst() {
        let moves: [(CGFloat, Double)] = [(10, 0.05), (0, 0.05), (-8, 0.04), (0, 0.05), (6, 0.03), (0, 0)]
        var t = 0.0
        for (offset, dur) in moves {
            DispatchQueue.main.asyncAfter(deadline: .now() + t) {
                withAnimation(.linear(duration: 0.04)) { glitchOffsetX = offset }
            }
            t += dur
        }
        HapticManager.shared.playTypeHaptic()
    }
}

// ── Alex Notifications ──────────────────────────────────────────────────────
struct AlexNotificationCard: View {
    let message: String
    let time: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            // Ikon Pengirim (Alex)
            Image(systemName: "person.circle.fill")
                .resizable()
                .frame(width: 40, height: 40)
                .foregroundColor(.white.opacity(0.8))
                .padding(.top, 5)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("ALEX")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundColor(.red.opacity(0.9))
                    
                    Spacer()
                    
                    Text(time)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.gray)
                }
                
                Text(message)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(15)
        .background(
            // Efek kaca transparan (Glassmorphism)
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .padding(.horizontal, 25)
        .padding(.vertical, 5)
    }
}

// ── Menu Button ─────────────────────────────────────────────────────────────

private struct MenuButton: View {
    let title: String
    let icon: String
    let tint: Color
    var prominent: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(prominent ? .black : tint)
                    .frame(width: 22)
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundColor(prominent ? .black : tint)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(prominent ? .black.opacity(0.5) : tint.opacity(0.35))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 15)
            .background(
                prominent
                ? Color.white
                : tint.opacity(0.07),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(prominent ? Color.clear : tint.opacity(0.18), lineWidth: 1)
            )
        }
    }
}


private struct ChoiceGuideRow: View {
    let color: Color
    let label: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(color)
                .frame(width: 52)
                .padding(.vertical, 6)
                .background(color.opacity(0.15))
                .overlay(Capsule().stroke(color.opacity(0.35), lineWidth: 1))
                .clipShape(Capsule())
                .padding(.top, 2)

            Text(description)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .lineSpacing(3)

            Spacer()
        }
    }
}


// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: SETTINGS SHEET
// MARK: ─────────────────────────────────────────────────────────────────────

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var settings = AppSettings.shared
    @State private var showResetConfirm = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {

                    // ── Header ───────────────────────────────────────────────
                    Text("SETTINGS")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                        .tracking(5)
                        .padding(.top, 50)
                        .frame(maxWidth: .infinity, alignment: .center)

                    // ── Audio Section ────────────────────────────────────────
                    SettingsSection(title: "AUDIO") {
                        VStack(spacing: 20) {
                            SettingsSlider(
                                label: "Music Volume",
                                icon: "music.note",
                                value: $settings.musicVolume
                            )
                            SettingsSlider(
                                label: "SFX & Ambience",
                                icon: "waveform",
                                value: $settings.sfxVolume
                            )
                        }
                    }

                    // ── Experience Section ───────────────────────────────────
                    SettingsSection(title: "EXPERIENCE") {
                        VStack(spacing: 16) {
                            Toggle(isOn: $settings.hapticsEnabled) {
                                HStack(spacing: 10) {
                                    Image(systemName: "iphone.radiowaves.left.and.right")
                                        .foregroundColor(.gray)
                                        .frame(width: 22)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Haptic Feedback")
                                            .font(.subheadline)
                                            .foregroundColor(.white)
                                        Text("Heartbeat, glitches & jump events")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            .tint(.blue)

                            Toggle(isOn: $settings.debugBarVisible) {
                                HStack(spacing: 10) {
                                    Image(systemName: "ladybug")
                                        .foregroundColor(.gray)
                                        .frame(width: 22)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Developer Debug Bar")
                                            .font(.subheadline)
                                            .foregroundColor(.white)
                                        Text("Shows denial score, act, scene, model mode")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            .tint(.orange)
                        }
                    }

                    // ── Data Section ─────────────────────────────────────────
                    SettingsSection(title: "DATA") {
                        VStack(spacing: 12) {
                            // Reset tutorial
                            Button {
                                settings.resetProgress()
                                HapticManager.shared.playTypeHaptic()
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.counterclockwise")
                                        .foregroundColor(.orange)
                                    Text("Reset Tutorial")
                                        .foregroundColor(.orange)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 13)
                                .background(Color.orange.opacity(0.08))
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.2), lineWidth: 1))
                            }

                            // Reset all progress
                            Button {
                                showResetConfirm = true
                            } label: {
                                HStack {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                    Text("Reset All Game Data")
                                        .foregroundColor(.red)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 13)
                                .background(Color.red.opacity(0.08))
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.red.opacity(0.2), lineWidth: 1))
                            }
                            .confirmationDialog(
                                "This will erase all settings and tutorial progress.",
                                isPresented: $showResetConfirm,
                                titleVisibility: .visible
                            ) {
                                Button("Reset Everything", role: .destructive) {
                                    settings.resetProgress()
                                    settings.musicVolume = 0.5
                                    settings.sfxVolume = 0.8
                                    settings.hapticsEnabled = true
                                    HapticManager.shared.playGlitchHaptic()
                                }
                                Button("Cancel", role: .cancel) {}
                            }
                        }
                    }

                    // ── Version ──────────────────────────────────────────────
                    Text("READ AT 2:14 AM  ·  v1.0")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.gray.opacity(0.35))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 8)

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
            }
        }
        .overlay(
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray)
                    .padding(16)
                    .background(Color.white.opacity(0.08), in: Circle())
            }
            .padding(16),
            alignment: .topTrailing
        )
    }
}

// ── Settings Section Container ───────────────────────────────────────────────

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
                .tracking(3)
            content
        }
    }
}

// ── Volume Slider ────────────────────────────────────────────────────────────

private struct SettingsSlider: View {
    let label: String
    let icon: String
    @Binding var value: Float

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.gray)
                    .frame(width: 20)
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.white)
                Spacer()
                Text("\(Int(value * 100))%")
                    .font(.caption.monospaced())
                    .foregroundColor(.gray)
            }
            Slider(value: $value, in: 0...1)
                .tint(.white.opacity(0.7))
        }
    }
}
