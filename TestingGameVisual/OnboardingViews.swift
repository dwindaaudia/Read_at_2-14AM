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

        // Fade to Homescreen after last line
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

/// Snapshot of lock-screen notification `ScrollView` geometry for edge fades.
private struct LockScrollFadeMetrics: Equatable {
    var offsetY: CGFloat
    var contentH: CGFloat
    var visibleH: CGFloat
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        abs(lhs.offsetY - rhs.offsetY) < 0.55
            && abs(lhs.contentH - rhs.contentH) < 0.55
            && abs(lhs.visibleH - rhs.visibleH) < 0.55
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: HOMESCREEN (Lock screen + main hub)
// MARK: ─────────────────────────────────────────────────────────────────────

/// Matches `chatHeaderBarColor` in chat — dark maroon dock, not bright pink-red.
private let homeScreenDockBarColor = Color(red: 0.11, green: 0.0, blue: 0.02)

struct HomescreenView: View {
    @ObservedObject var gameManager: GameManager
    @Binding var chatUnlocked: Bool
    let onOpenChat: () -> Void

    @State private var titleOpacity: Double = 0
    @State private var buttonsOpacity: Double = 0
    @State private var glitchOffsetX: CGFloat = 0
    @State private var showSettings = false
    @State private var showFiles = false
    @State private var glitchTimer: Timer?

    @State private var clockDigits = "2:14"
    @State private var brightnessDim: Double = 0
    @State private var glitchFlash: Double = 0
    @State private var ghostNotifications: [GhostNotification] = []
    @State private var showAlexNotification = false
    @State private var introStarted = false
    @State private var ghostPhaseHidden = true
    @State private var lockScrollTopFade: Double = 0
    @State private var lockScrollBottomFade: Double = 0

    private var chapterLabel: String {
        "Chapter 1"
    }
    
    private var shouldShowNotificationsSection: Bool {
        if hasReturningFeed { return !lockScreenAlexQueue.isEmpty }
        if !ghostPhaseHidden { return true }
        return showAlexNotification
    }
    
    private var showNotificationSectionHeader: Bool {
        if hasReturningFeed { return !lockScreenAlexQueue.isEmpty }
        return showAlexNotification
    }

    var body: some View {
        ZStack {
            Image("ls_wallpaper")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
                .opacity(0.5)

            Color.black.opacity(brightnessDim).ignoresSafeArea()
            Color.red.opacity(glitchFlash).ignoresSafeArea().allowsHitTesting(false)
            VStack(spacing: 0) {
                ForEach(0..<50, id: \.self) { i in
                    Color.white
                        .opacity(i % 4 == 0 ? 0.025 : 0)
                        .frame(height: 2)
                    Color.clear.frame(height: 14)
                }
            }
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                HStack {
                    Text("Friday 8")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.trailing, 18)

                    ZStack {
                        Text(clockDigits)
                            .font(.system(size: 56, weight: .black))
                            .foregroundColor(.red.opacity(0.55))
                            .offset(x: glitchOffsetX + 3, y: 2)
                        Text(clockDigits)
                            .font(.system(size: 56, weight: .black))
                            .foregroundColor(.cyan.opacity(0.35))
                            .offset(x: -glitchOffsetX - 2, y: -2)
                        Text(clockDigits)
                            .font(.system(size: 56, weight: .black))
                            .foregroundColor(.white)
                    }
                    .opacity(titleOpacity)

                    Text(chapterLabel)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.leading, 18)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 72)

                Spacer()

                if shouldShowNotificationsSection {
                    VStack(alignment: .leading, spacing: 10) {
                        if showNotificationSectionHeader {
                            HStack {
                                Text("Notifications")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                                Spacer()
                                Button("Clear All") {
                                    clearLockScreenAlexNotifications()
                                }
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.75))
                            }
                            .padding(.horizontal, 20)
                        }

                        ZStack {
                            ScrollView(.vertical, showsIndicators: false) {
                                VStack(spacing: 10) {
                                    if hasReturningFeed {
                                        ForEach(lockScreenAlexQueue) { row in
                                            AlexNotificationCard(
                                                message: row.text,
                                                time: row.time,
                                                isInteractive: chatUnlocked,
                                                onTap: chatUnlocked ? { openChatIfAllowed() } : nil
                                            )
                                        }
                                    } else {
                                        if !ghostPhaseHidden {
                                            ForEach(ghostNotifications) { g in
                                                GhostNotificationRow(title: g.title, message: g.message)
                                            }
                                        }
                                        if showAlexNotification {
                                            AlexNotificationCard(
                                                message: "Are you awake?",
                                                time: "2:14 AM",
                                                isInteractive: chatUnlocked,
                                                onTap: chatUnlocked ? { openChatIfAllowed() } : nil
                                            )
                                            .transition(.move(edge: .bottom).combined(with: .opacity))
                                        }
                                    }
                                }
                                .padding(.top, 12)
                                .padding(.bottom, 8)
                            }
                            .scrollBounceBehavior(.basedOnSize)
                            .onScrollGeometryChange(for: LockScrollFadeMetrics.self) { geo in
                                LockScrollFadeMetrics(
                                    offsetY: geo.contentOffset.y,
                                    contentH: geo.contentSize.height,
                                    visibleH: geo.visibleRect.height
                                )
                            } action: { _, metrics in
                                applyLockScrollEdgeFades(metrics)
                            }
                            
                            VStack(spacing: 0) {
                                LinearGradient(
                                    colors: [Color.black.opacity(0.68), Color.black.opacity(0)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                .frame(height: 54)
                                .opacity(lockScrollTopFade)
                                
                                Spacer(minLength: 0)
                                
                                LinearGradient(
                                    colors: [Color.black.opacity(0), Color.black.opacity(0.68)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                .frame(height: 54)
                                .opacity(lockScrollBottomFade)
                            }
                            .allowsHitTesting(false)
                        }
                        .frame(maxHeight: 360)
                        .clipped()
                    }
                }

                Spacer(minLength: 12)

                HStack {
                    homeDockButton(title: "SETTINGS", systemImage: "gearshape.fill") {
                        showSettings = true
                    }

                    homeDockButton(title: "CHAT", systemImage: "message.fill", disabled: !chatUnlocked) {
                        openChatIfAllowed()
                    }
                    .opacity(chatUnlocked ? 1 : 0.35)

                    homeDockButton(title: "FILES", systemImage: "folder.fill") {
                        showFiles = true
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 18)
                .padding(.bottom, 26)
                .frame(maxWidth: .infinity)
                .background {
                    homeScreenDockBarColor
                        .ignoresSafeArea(edges: .bottom)
                }
                .opacity(buttonsOpacity)
            }
        }
        .onAppear {
            withAnimation(.easeIn(duration: 1.0)) { titleOpacity = 1.0 }
            withAnimation(.easeIn(duration: 0.8).delay(0.4)) { buttonsOpacity = 1.0 }
            startGlitchLoop()
            configureHomeOnAppear()
            gameManager.resumePendingAlexReplyIfNeeded()
        }
        .onChange(of: gameManager.messages) { _, _ in
            if !gameManager.messages.isEmpty { chatUnlocked = true }
        }
        .onDisappear { glitchTimer?.invalidate() }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showFiles) {
            FilesEvidenceView(gameManager: gameManager)
        }
    }
    
    /// Edge shadows only after the user scrolls away from the “resting” top; no permanent vignette when idle.
    private func applyLockScrollEdgeFades(_ m: LockScrollFadeMetrics) {
        guard m.visibleH > 1, m.contentH > 1 else {
            lockScrollTopFade = 0
            lockScrollBottomFade = 0
            return
        }
        let overflow = m.contentH - m.visibleH
        if overflow < 2 {
            lockScrollTopFade = 0
            lockScrollBottomFade = 0
            return
        }
        let maxY = max(0, overflow - 1)
        let y = max(0, m.offsetY)
        let spaceBelow = max(0, maxY - y)
        let edge: CGFloat = 8
        let span: CGFloat = 28
        if y <= edge {
            lockScrollTopFade = 0
        } else {
            lockScrollTopFade = min(0.92, Double((y - edge) / span))
        }
        if spaceBelow <= edge {
            lockScrollBottomFade = 0
        } else {
            lockScrollBottomFade = min(0.92, Double((spaceBelow - edge) / span))
        }
    }

    private func clearLockScreenAlexNotifications() {
        let ids = Set(lockScreenAlexQueue.map(\.id))
        guard !ids.isEmpty else { return }
        gameManager.markAlexMessagesRead(ids: ids)
        GameSaveManager.shared.save(from: gameManager)
    }

    private var hasReturningFeed: Bool {
        GameSaveManager.shared.hasSave || !gameManager.messages.isEmpty
    }
    
    /// Unread inbound Alex rows (same read model as the chat thread: opening chat marks them read).
    private var lockScreenAlexQueue: [AlexFeedRow] {
        gameManager.messages.compactMap { msg in
            guard !msg.isFromMe, !msg.isRead else { return nil }
            let preview: String?
            switch msg.type {
            case .text:
                let t = msg.text.trimmingCharacters(in: .whitespacesAndNewlines)
                preview = t.isEmpty ? nil : t
            case .systemAlert:
                let t = msg.text.trimmingCharacters(in: .whitespacesAndNewlines)
                preview = t.isEmpty ? nil : t
            case .image:
                let t = msg.text.trimmingCharacters(in: .whitespacesAndNewlines)
                preview = t.isEmpty ? "Photo" : t
            case .voiceNote:
                preview = "Voice message"
            case .lockedFile:
                preview = msg.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "File" : msg.text
            }
            guard let preview else { return nil }
            return AlexFeedRow(id: msg.id, text: preview, time: msg.time)
        }
    }
    
    private func configureHomeOnAppear() {
        if hasReturningFeed {
            clockDigits = "2:14"
            chatUnlocked = true
            showAlexNotification = false
            return
        }
        guard !introStarted else { return }
        introStarted = true
        clockDigits = "2:13"
        chatUnlocked = false
        ghostPhaseHidden = false
        showAlexNotification = false
        ghostNotifications = GhostNotification.randomTriple()
        runNewPlayerIntro()
    }

    private func runNewPlayerIntro() {
        // First-time flow: clock flips to 2:14 + glitch → short beat → ghost chats dismiss → pause → Alex notification.
        let clockAndGlitch: TimeInterval = 5.0
        let pauseAfterGlitch: TimeInterval = 0.42
        let pauseBeforeAlex: TimeInterval = 0.72
        
        DispatchQueue.main.asyncAfter(deadline: .now() + clockAndGlitch) {
            clockDigits = "2:14"
            runGlitchBurst()
            HapticManager.shared.playGlitchHaptic()
            withAnimation(.easeInOut(duration: 0.1)) { glitchFlash = 0.38 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                glitchFlash = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + pauseAfterGlitch) {
                withAnimation(.easeOut(duration: 0.48)) {
                    ghostPhaseHidden = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + pauseBeforeAlex) {
                    withAnimation(.spring(response: 0.58, dampingFraction: 0.82)) {
                        showAlexNotification = true
                    }
                    AudioManager.shared.playSound("notification_sfx")
                    HapticManager.shared.playGlitchHaptic()
                    chatUnlocked = true
                }
            }
        }
    }

    private func openChatIfAllowed() {
        guard chatUnlocked else { return }
        HapticManager.shared.playTypeHaptic()
        onOpenChat()
    }

    private func homeDockButton(title: String, systemImage: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: {
            guard !disabled else { return }
            HapticManager.shared.playTypeHaptic()
            action()
        }) {
            VStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 30))
                    .foregroundColor(.white)
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
        }
        .disabled(disabled)
    }
    private func startGlitchLoop() {
        scheduleNextGlitch()
    }

    private func scheduleNextGlitch() {
        let waitTime = Double.random(in: 4.0...9.0)
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

struct AlexNotificationCard: View {
    let message: String
    let time: String
    var isInteractive: Bool = true
    var onTap: (() -> Void)? = nil
    
    var body: some View {
        Group {
            if let onTap, isInteractive {
                Button(action: onTap) { cardContent }
                    .buttonStyle(.plain)
            } else {
                cardContent
            }
        }
        .opacity(isInteractive ? 1 : 0.5)
    }
    
    private var cardContent: some View {
        HStack(alignment: .top, spacing: 15) {
            Image("alex pp")
                .resizable()
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Alex")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text(time)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                }
                
                Text(message)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(15)
        .background(
            Color.red.opacity(0.25)
        )
        .overlay(
            VStack {
                Rectangle()
                    .fill(Color.red.opacity(0.5))
                    .frame(height: 1)
                
                Spacer()
                
                Rectangle()
                    .fill(Color.red.opacity(0.5))
                    .frame(height: 1)
            }
        )
        .padding(.horizontal, 25)
        .padding(.vertical, 5)
    }
}

private struct AlexFeedRow: Identifiable {
    let id: UUID
    let text: String
    let time: String
}

private struct GhostNotification: Identifiable {
    let id = UUID()
    let title: String
    let message: String

    static func randomTriple() -> [GhostNotification] {
        let pool: [(String, String)] = [
            ("Instagram", "Someone liked your photo."),
            ("Mail", "Your bank statement is ready."),
            ("Weather", "Heavy rain expected after midnight."),
            ("Calendar", "Reminder: Flight check-in opens."),
            ("News", "Breaking: local tower outage reported."),
            ("Fitness", "You haven't closed your rings today."),
            ("Podcasts", "New episode: \"Signals in the Static\"."),
            ("Maps", "Traffic is lighter than usual."),
            ("Wallet", "Transaction declined — insufficient funds."),
            ("Health", "Audio levels were high last night.")
        ]
        return pool.shuffled().prefix(3).map { GhostNotification(title: $0.0, message: $0.1) }
    }
}

private struct GhostNotificationRow: View {
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.15))
                .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Text("2:13 AM")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.45))
                }
                Text(message)
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.92))
                    .lineLimit(2)
            }
        }
        .padding(14)
        .background(Color.red.opacity(0.22))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.red.opacity(0.45), lineWidth: 1)
        )
        .padding(.horizontal, 20)
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
