import SwiftUI

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: 1. SPLASH SCREEN — Fake OS Boot Sequence
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
        BootLine("LOADING: READ_AT_0214.app",              color: .white,  delay: 3.70),
        BootLine("████████████████████  100%",             color: .white,  delay: 4.30),
        BootLine("",                                       color: .clear,  delay: 4.50),
        BootLine("> CONNECTION ESTABLISHED",               color: .green,  delay: 4.90),
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

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
// MARK: 2. MAIN MENU
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
            Color.black.ignoresSafeArea()

            // Subtle scanlines overlay
            VStack(spacing: 0) {
                ForEach(0..<50, id: \.self) { i in
                    Color.white
                        .opacity(i % 4 == 0 ? 0.025 : 0)
                        .frame(height: 2)
                    Color.clear.frame(height: 14)
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // ── Content ────────────────────────────────────────────────────
            VStack(spacing: 0) {

                Spacer()

                // Glitch Title
                ZStack {
                    // Red chromatic ghost
                    Text("Read at 2:14 AM")
                        .font(.system(size: 32, weight: .black))
                        .foregroundColor(.red.opacity(0.55))
                        .offset(x: glitchOffsetX + 3, y: 2)

                    // Cyan chromatic ghost
                    Text("Read at 2:14 AM")
                        .font(.system(size: 32, weight: .black))
                        .foregroundColor(.cyan.opacity(0.35))
                        .offset(x: -glitchOffsetX - 2, y: -2)

                    // Main white title
                    Text("Read at 2:14 AM")
                        .font(.system(size: 32, weight: .black))
                        .foregroundColor(.white)
                }
                .opacity(titleOpacity)

                Text("A P S Y C H O L O G I C A L  H O R R O R  E X P E R I E N C E")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundColor(.gray.opacity(0.7))
                    .tracking(1)
                    .padding(.top, 10)
                    .opacity(titleOpacity)

                Spacer()

                // ── Menu Buttons ───────────────────────────────────────────
                VStack(spacing: 12) {
                    if GameSaveManager.shared.hasSave {
                        MenuButton(title: "CONTINUE", icon: "arrow.right.circle", tint: .green, prominent: true) {
                            HapticManager.shared.playTypeHaptic()
                            withAnimation(.easeIn(duration: 0.3)) { buttonsOpacity = 0 }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { onContinue() }
                        }
                        if let dateStr = GameSaveManager.shared.savedDateString {
                            Text("Last played: \(dateStr)")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.gray.opacity(0.5))
                                .padding(.top, -6)
                        }
                    }
                    MenuButton(title: "NEW GAME", icon: "play.fill", tint: .white, prominent: !GameSaveManager.shared.hasSave) {
                        HapticManager.shared.playTypeHaptic()
                        withAnimation(.easeIn(duration: 0.3)) { buttonsOpacity = 0 }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { onNewGame() }
                    }
                    MenuButton(title: "ACHIEVEMENTS", icon: "trophy", tint: .yellow) {
                                            HapticManager.shared.playTypeHaptic()
                                            showAchievements = true
                                        }
                    MenuButton(title: "HOW TO PLAY", icon: "questionmark.circle", tint: .gray) {
                        HapticManager.shared.playTypeHaptic()
                        showHowToPlay = true
                    }
                    MenuButton(title: "SETTINGS", icon: "gearshape", tint: .gray) {
                        HapticManager.shared.playTypeHaptic()
                        showSettings = true
                    }
                    MenuButton(title: "CREDITS", icon: "person.2", tint: .gray) {
                        HapticManager.shared.playTypeHaptic()
                        showCredits = true
                    }
                }
                .opacity(buttonsOpacity)
                .padding(.horizontal, 36)
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
        .sheet(isPresented: $showCredits)   { CreditsView() }
        .sheet(isPresented: $showHowToPlay) { HowToPlayView() }
        .sheet(isPresented: $showAchievements) { AchievementsView() }
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




// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: 3. HOW TO PLAY SHEET
// MARK: ─────────────────────────────────────────────────────────────────────

struct HowToPlayView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {

                    // Header
                    VStack(spacing: 6) {
                        Text("HOW TO PLAY")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.gray)
                            .tracking(4)
                            .padding(.top, 50)

                        Text("Your choices shape\nAlex's reality.")
                            .font(.system(size: 26, weight: .black))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    }

                    // Choice guide
                    VStack(spacing: 14) {
                        ChoiceGuideRow(
                            color: .blue,
                            label: "TRUST",
                            description: "Believe Alex. Help him. Stay grounded in empathy."
                        )
                        ChoiceGuideRow(
                            color: .red,
                            label: "REJECT",
                            description: "Deny or fight the truth. Anger and fear as shield."
                        )
                        ChoiceGuideRow(
                            color: .gray,
                            label: "AVOID",
                            description: "Hesitate. Look away. Pretend nothing is wrong."
                        )
                    }
                    .padding(.horizontal, 4)

                    Divider().background(Color.white.opacity(0.1))

                    // Story premise
                    VStack(alignment: .leading, spacing: 10) {
                        Text("THE STORY")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.gray)
                            .tracking(3)

                        Text("You receive a message from Alex — a best friend who disappeared five years ago. For you, it's been 1,826 days of silence. For Alex, no time has passed at all.")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.8))
                            .lineSpacing(4)

                        Text("What happened on October 18, 2019 at 2:14 AM?")
                            .font(.body.italic())
                            .foregroundColor(.gray)
                            .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 28)
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
// MARK: 4. CREDITS SHEET
// MARK: ─────────────────────────────────────────────────────────────────────

struct CreditsView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 30) {

                    Text("CREDITS")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                        .tracking(5)
                        .padding(.top, 50)

                    // Credit blocks
                    VStack(spacing: 22) {
                        CreditBlock(role: "GAME DESIGN & DEVELOPMENT",  name: "SHOPEE")
                        CreditBlock(role: "NARRATIVE & WRITING",        name: "TOKPED")
                        CreditBlock(role: "VISUAL EFFECTS",             name: "LAZADA")
                        CreditBlock(role: "SOUND DESIGN & MUSIC",       name: "BLIBLI")
                    }

                    Divider().background(Color.white.opacity(0.1)).padding(.horizontal, 30)

                    VStack(spacing: 8) {
                        Text("Powered by Apple FoundationModels")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.gray)
                        Text("Built with SwiftUI & SpriteKit")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.gray.opacity(0.6))
                    }

                    VStack(spacing: 6) {
                        Text("\"Are you awake?\"")
                            .font(.system(size: 15).italic())
                            .foregroundColor(.gray.opacity(0.5))
                        Text("— Alex, 2:14 AM, October 18, 2019")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.gray.opacity(0.3))
                    }
                    .padding(.top, 4)

                    Spacer(minLength: 60)
                }
                .padding(.horizontal, 28)
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

private struct CreditBlock: View {
    let role: String
    let name: String

    var body: some View {
        VStack(spacing: 5) {
            Text(role)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundColor(.gray)
                .tracking(3)
            Text(name)
                .font(.system(size: 19, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: 5. ACHIEVEMENTS / ENDINGS GALLERY
// MARK: ─────────────────────────────────────────────────────────────────────

struct AchievementsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var settings = AppSettings.shared

    // Data master dari ketiga ending yang ada di dalam game
    let allEndings: [(title: String, desc: String, color: Color, icon: String)] = [
        ("THE SAVIOR", "You chose empathy over fear. You remembered Alex when everyone else forgot.", .blue, "heart.fill"),
        ("THE DENIER", "You fought the truth until the end. Your skepticism is a shield for your own guilt.", .red, "xmark.shield.fill"),
        ("THE COWARD", "You ran from the truth. Avoidance was your only escape from the 2:14 loop.", .gray, "eye.slash.fill")
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    
                    // ── Header
                    VStack(spacing: 6) {
                        Text("THE ARCHIVES")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.gray)
                            .tracking(5)
                            .padding(.top, 50)
                        
                        Text("\(settings.unlockedEndings.count) / 3 ENDINGS UNLOCKED")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                    }

                    // ── List of Cards
                    VStack(spacing: 24) {
                        ForEach(allEndings, id: \.title) { ending in
                            let isUnlocked = settings.unlockedEndings.contains(ending.title)
                            
                            AchievementCard(
                                title: ending.title,
                                description: ending.desc,
                                color: ending.color,
                                icon: ending.icon,
                                isUnlocked: isUnlocked
                            )
                        }
                    }
                    .padding(.horizontal, 24)

                    Spacer(minLength: 40)
                }
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

private struct AchievementCard: View {
    let title: String
    let description: String
    let color: Color
    let icon: String
    let isUnlocked: Bool

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? color.opacity(0.12) : Color.white.opacity(0.05))
                    .frame(width: 50, height: 50)
                Image(systemName: isUnlocked ? icon : "lock.fill")
                    .font(.system(size: 22))
                    .foregroundColor(isUnlocked ? color : .gray.opacity(0.5))
            }

            Text(isUnlocked ? title : "CLASSIFIED")
                .font(.system(size: 24, weight: .black))
                .foregroundColor(isUnlocked ? color : .gray.opacity(0.5))
                .tracking(isUnlocked ? 0 : 4)

            Text(isUnlocked ? description : "This timeline remains undiscovered. Play again and change your choices.")
                .font(.system(size: 13))
                .foregroundColor(isUnlocked ? .white.opacity(0.8) : .gray.opacity(0.4))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(isUnlocked ? 0.04 : 0.02))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isUnlocked ? color.opacity(0.4) : Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: 6. SETTINGS SHEET
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


