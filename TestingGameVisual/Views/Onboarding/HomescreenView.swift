import SwiftUI

// MARK: - HOMESCREEN (Lock screen + main hub)
// Combines the previous SplashScreen → MainMenu → ContentWarning → LockScreen flow
// into a single dark home hub with a unread Alex feed and three dock buttons.

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

/// Matches `chatHeaderBarColor` in chat — dark maroon dock, not bright pink-red.
private let homeScreenDockBarColor = Color(red: 0.11, green: 0.0, blue: 0.02)

struct HomescreenView: View {
    @ObservedObject var gameManager: GameManager
    @Binding var chatUnlocked: Bool
    let onOpenChat: () -> Void
    /// Injected by the root so the Settings "Reset All Game Data" action can wipe
    /// save / evidence / totalClears / game state and rebuild the home hub.
    var onResetAll: (() -> Void)? = nil

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

    private var chapterLabel: String { "Chapter 1" }

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

            scanlineOverlay

            VStack(spacing: 0) {
                titleHeader
                Spacer()
                if shouldShowNotificationsSection { notificationsSection }
                Spacer(minLength: 12)
                dockSection
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
        .sheet(isPresented: $showSettings) { SettingsView(onResetAll: onResetAll) }
        .sheet(isPresented: $showFiles) {
            FilesEvidenceView(gameManager: gameManager)
        }
    }

    // MARK: Subviews

    private var scanlineOverlay: some View {
        VStack(spacing: 0) {
            ForEach(0..<50, id: \.self) { i in
                Color.white
                    .opacity(i % 4 == 0 ? 0.025 : 0)
                    .frame(height: 2)
                Color.clear.frame(height: 14)
            }
        }
        .allowsHitTesting(false)
    }

    private var titleHeader: some View {
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
    }

    private var notificationsSection: some View {
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

    private var dockSection: some View {
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

    // MARK: Lock-Feed Logic

    /// Edge shadows only after the user scrolls away from the "resting" top; no permanent vignette when idle.
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

    // MARK: Glitch Loop

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

// MARK: - Lock-Feed Helper Types

struct AlexFeedRow: Identifiable {
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
