import SwiftUI

// MARK: - Chat Room View
// ─────────────────────────────────────────────────────────────────────────────

struct ChatRoomView: View {
    @ObservedObject var gameManager: GameManager
    let onReturnToMenu: () -> Void

    private enum ChatThreadRow: Identifiable {
        case chapter(String)
        case message(Message)

        var id: String {
            switch self {
            case .chapter(let title): return "chapter-\(title)"
            case .message(let m): return m.id.uuidString
            }
        }
    }

    @State private var showTutorial      = false
    @State private var showActTransition = false
    @State private var transitionActNumber  = 2
    @State private var shownActTransitions  = Set<Int>()

    /// Chapter 1 end-of-build sequence: pause → footer → short "Coming soon" → dismiss (chat stays readable).
    private enum Chapter1EndingPhase: Equatable {
        case idle
        case chapterFooter
        case comingSoonTeaser
        case finished
    }

    @State private var chapter1EndingPhase: Chapter1EndingPhase = .idle
    @State private var chapter1EndingRunID: Int = 0
    @State private var chapter1EndingSequenceLock = false
    @State private var comingSoonTeaserScale: CGFloat = 0.88
    @State private var comingSoonTeaserOpacity: Double = 0

    private let chapter1EndInitialDelay: Duration = .seconds(2.5)
    private let chapter1EndFooterHold: Duration = .seconds(3.0)
    private let chapter1EndTeaserHold: Duration = .seconds(2.5)

    private var chapter1ChatBottomInsetForEnding: CGFloat {
        guard gameManager.currentScene == "ENDING",
              gameManager.isEndingFinished,
              chapter1EndingPhase == .chapterFooter else { return 0 }
        return 120
    }

    private var alexStatusText: String {
        if gameManager.currentScene == "ENDING" { return "Offline" }
        if gameManager.isTyping { return "typing…" }
        return "Online"
    }

    private var chatThreadRows: [ChatThreadRow] {
        let msgs = gameManager.messages
        guard !msgs.isEmpty else { return [] }
        var rows: [ChatThreadRow] = []
        rows.append(.chapter("Chapter 1"))
        for m in msgs { rows.append(.message(m)) }
        return rows
    }

    private var showChoiceStrip: Bool {
        gameManager.currentScene != "ENDING" && !gameManager.currentChoices.isEmpty
    }

//    private var chatHeaderBarColor: Color {
//        Color(red: 0.11, green: 0.0, blue: 0.02)
//    }
    private var chatHeaderBarGradient: LinearGradient {
        // Translating Hex #600606 to RGB
        let baseColor = Color(red: 96 / 255.0, green: 6 / 255.0, blue: 6 / 255.0)
        
        return LinearGradient(
            gradient: Gradient(colors: [
                baseColor.opacity(0.0), // Top: 0% opacity
                baseColor.opacity(1.0)  // Bottom: 100% opacity
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
    }
    private var chatFooterBarGradient: LinearGradient {
        // Translating Hex #600606 to RGB
        let baseColor = Color(red: 96 / 255.0, green: 6 / 255.0, blue: 6 / 255.0)
        
        return LinearGradient(
            gradient: Gradient(colors: [
                 // Top: 100% opacity
                baseColor.opacity(1.0),
                Color(red:75 / 255.0, green:5 / 255.0, blue:5 / 255.0)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func goHome() {
        gameManager.isPlayerInChat = false
        GameSaveManager.shared.save(from: gameManager)
        onReturnToMenu()
    }

    var body: some View {
        NavigationStack {
            chatRoomNavigationContent
        }
        .checkRealTimeEvent(manager: gameManager)
    }

    @ViewBuilder
    private var chatRoomNavigationContent: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()
            chatMainStack
            chatOverlayStack
        }
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top, spacing: 0) {
            chatCustomHeader
        }
        .onAppear {
            gameManager.isPlayerInChat = true
            gameManager.markAlexInboundMessagesRead()
            // Audit §10.1: warm the on-device LLM the moment the player is in chat —
            // they're about to interact, and the first reply pays the cold-start cost.
            gameManager.prewarmAIIfAvailable()
            if !AppSettings.shared.hasSeenTutorial {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeIn(duration: 0.4)) { showTutorial = true }
                }
            }
            resumeAmbientEffectsIfNeeded()
            if gameManager.currentScene == "ENDING", gameManager.isEndingFinished {
                scheduleChapter1EndingSequenceIfNeeded()
            }
        }
        .onDisappear {
            gameManager.isPlayerInChat = false
            if chapter1EndingPhase != .finished {
                cancelChapter1EndingSequence(resetPhase: true)
            } else {
                cancelChapter1EndingSequence(resetPhase: false)
            }
        }
        .onChange(of: gameManager.isEndingFinished) { _, finished in
            if finished, gameManager.currentScene == "ENDING" {
                scheduleChapter1EndingSequenceIfNeeded()
            } else if !finished {
                cancelChapter1EndingSequence(resetPhase: true)
            }
        }
        .onChange(of: gameManager.currentScene) { _, newScene in
            if newScene != "ENDING" {
                cancelChapter1EndingSequence(resetPhase: true)
            } else if gameManager.isEndingFinished {
                scheduleChapter1EndingSequenceIfNeeded()
            }
        }
        .onChange(of: gameManager.currentAct) { _, newAct in
            guard newAct > 1, !shownActTransitions.contains(newAct) else { return }
            shownActTransitions.insert(newAct)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                transitionActNumber = newAct
                withAnimation { showActTransition = true }
            }
        }
        .onChange(of: gameManager.shouldQuit) { _, quit in
            if quit {
                gameManager.shouldQuit = false
                GameSaveManager.shared.clearSave()
                AudioManager.shared.stopBackgroundMusic()
                AudioManager.shared.playBackgroundMusic(filename: "Horror")
                onReturnToMenu()
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 40, coordinateSpace: .local)
                .onEnded { value in
                    if value.translation.width > 100 && abs(value.translation.height) < 120 {
                        HapticManager.shared.playTypeHaptic()
                        goHome()
                    }
                }
        )
    }

    // MARK: Custom Header

    private var chatCustomHeader: some View {
        HStack(alignment: .center, spacing: 0) {
            Button {
                HapticManager.shared.playTypeHaptic()
                goHome()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            Rectangle()
                .fill(Color.white.opacity(0.22))
                .frame(width: 1, height: 28)
                .padding(.horizontal, 8)

            HStack(spacing: 10) {
                Image("alex pp")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 36)
                    .clipShape(Rectangle())
                    .overlay(
                        Rectangle()
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Alex")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                    Text(alexStatusText)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white.opacity(0.62))
                }
                .fixedSize(horizontal: true, vertical: true)
            }

            Spacer(minLength: 0)

            EvidenceBoardButton(gameManager: gameManager)
                .buttonStyle(.plain)
                .padding(.trailing, 4)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .background(chatHeaderBarGradient)
    }

    // MARK: Main Stack

    @ViewBuilder
    private var chatMainStack: some View {
        VStack(spacing: 0) {
            if AppSettings.shared.debugBarVisible && gameManager.currentScene != "ENDING" {
                DebugStatusView(
                    denialScore:  gameManager.denialScore,
                    currentAct:   gameManager.currentAct,
                    currentScene: gameManager.currentScene,
                    modelStatus:  gameManager.modelStatusText
                )
                .padding(.horizontal)
                .padding(.top, 8)
            }

            chatMessagesScroll

            if gameManager.currentScene != "ENDING" {
                VStack(spacing: showChoiceStrip ? 8 : 0) {
                    if showChoiceStrip {
                        ChoiceKeyboardView(
                            choices:     gameManager.currentChoices,
                            denialScore: gameManager.denialScore
                        ) { choice in
                            withAnimation {
                                gameManager.playerMadeChoice(choice)
                            }
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    chatComposerPlaceholder
                }
                .padding(.horizontal, 12)
                .padding(.top, showChoiceStrip ? 10 : 12)
                .padding(.bottom, 8)
                .background(chatFooterBarGradient)
            }
        }
    }

    private var chatMessagesScroll: some View {
        ScrollView {
            ScrollViewReader { proxy in
                VStack(spacing: 18) {
                    ForEach(chatThreadRows) { row in
                        switch row {
                        case .chapter(let title):
                            Text(title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.black.opacity(0.82))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 5)
                                .background(Color(red: 0.871, green: 0.871, blue: 0.871))
                                .frame(maxWidth: .infinity)
                        case .message(let message):
                            MessageBubbleEnhanced(message: message)
                                .id(message.id)
                        }
                    }

                    if gameManager.isTyping {
                        AlexTypingIndicatorView()
                            .id("TypingIndicator")
                    }

                    Color.clear.frame(height: 1).id("bottomAnchor")
                }
                .padding(.bottom, chapter1ChatBottomInsetForEnding)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        proxy.scrollTo("bottomAnchor", anchor: .bottom)
                    }
                }
                .onChange(of: gameManager.messages) { _, _ in
                    withAnimation(.spring()) { proxy.scrollTo("bottomAnchor", anchor: .bottom) }
                }
                .onChange(of: gameManager.isTyping) { _, isTyping in
                    if isTyping {
                        withAnimation(.spring()) { proxy.scrollTo("TypingIndicator", anchor: .bottom) }
                    }
                }
                .onChange(of: gameManager.currentChoices.count) { _, _ in
                    withAnimation(.spring()) { proxy.scrollTo("bottomAnchor", anchor: .bottom) }
                }
                .onChange(of: gameManager.currentScene) { _, newScene in
                    if newScene == "ENDING" {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            withAnimation(.easeOut(duration: 2.0)) {
                                proxy.scrollTo("bottomAnchor", anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .padding(.top, 4)
    }

    private var chatComposerPlaceholder: some View {
        HStack(spacing: 10) {
            Text(gameManager.currentChoices.isEmpty
                 ? "Waiting for Alex…"
                 : "Choose a response…")
            .foregroundColor(Color.black.opacity(0.45))
            .font(.system(size: 15, weight: .regular))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(white: 0.82))
        .overlay(Rectangle().stroke(Color.black.opacity(0.08), lineWidth: 1))
        .padding(.horizontal, 10)
    }

    // MARK: Overlays

    @ViewBuilder
    private var chatOverlayStack: some View {
        MemoryBleedOverlayView(
            denialScore:         gameManager.denialScore,
            recentAlexMessages:  gameManager.recentAlexReplies
        )
        .allowsHitTesting(false)
        .zIndex(5)

        GlitchSceneView(
            trigger:       gameManager.glitchTrigger,
            level:         gameManager.denialLevel,
            denialScore:   gameManager.denialScore,
            shadowTrigger: gameManager.shadowTrigger,
            crackTrigger:  gameManager.crackTrigger
        )
        .allowsHitTesting(false)

        if showTutorial {
            TutorialOverlayView(isVisible: $showTutorial)
                .transition(.opacity)
                .zIndex(90)
        }

        if showActTransition {
            ActTransitionView(
                actNumber: transitionActNumber,
                actTitle:  actTitleName(for: transitionActNumber),
                isVisible: $showActTransition
            )
            .transition(.opacity)
            .zIndex(80)
        }

        if gameManager.currentScene == "ENDING", gameManager.isEndingFinished,
           chapter1EndingPhase == .chapterFooter || chapter1EndingPhase == .comingSoonTeaser {
            chapter1EndingSequenceLayer
                .zIndex(200)
                .allowsHitTesting(chapter1EndingPhase == .comingSoonTeaser)
        }
    }

    // MARK: Chapter 1 Ending Sequence

    private var chapter1EndChapterFooterBanner: some View {
        VStack(spacing: 6) {
            Text("END OF CHAPTER 1")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .tracking(2.5)
                .foregroundColor(.white.opacity(0.92))
            Text("Acts I–III are all part of Chapter 1. This build is the full Chapter 1 arc.")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.white.opacity(0.56))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 4)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
        )
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
    }

    private var chapter1EndingSequenceLayer: some View {
        ZStack(alignment: .bottom) {
            if chapter1EndingPhase == .comingSoonTeaser {
                ZStack {
                    Color.black
                        .opacity(0.74 * comingSoonTeaserOpacity)
                        .ignoresSafeArea()

                    VStack {
                        Spacer(minLength: 0)
                        VStack(spacing: 14) {
                            Text("Coming soon")
                                .font(.system(size: 26, weight: .bold, design: .serif))
                                .foregroundColor(.white)
                            Text("More of Alex’s story")
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.48))
                                .tracking(1.5)
                            Text("You can scroll back through the thread above whenever you like.")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(.white.opacity(0.68))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 8)
                        }
                        .padding(.horizontal, 26)
                        .padding(.vertical, 28)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(Color.white.opacity(0.07))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                        )
                        .scaleEffect(comingSoonTeaserScale)
                        .opacity(comingSoonTeaserOpacity)
                        .padding(.horizontal, 28)
                        Spacer(minLength: 0)
                    }
                }
                .transition(.opacity)
            }

            if chapter1EndingPhase == .chapterFooter {
                chapter1EndChapterFooterBanner
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private func scheduleChapter1EndingSequenceIfNeeded() {
        guard gameManager.currentScene == "ENDING", gameManager.isEndingFinished else { return }
        guard chapter1EndingPhase == .idle else { return }
        guard !chapter1EndingSequenceLock else { return }

        chapter1EndingSequenceLock = true
        chapter1EndingRunID += 1
        let run = chapter1EndingRunID

        Task { @MainActor in
            try? await Task.sleep(for: chapter1EndInitialDelay)
            guard run == chapter1EndingRunID else { return }

            withAnimation(.easeOut(duration: 0.45)) {
                chapter1EndingPhase = .chapterFooter
            }

            try? await Task.sleep(for: chapter1EndFooterHold)
            guard run == chapter1EndingRunID else { return }

            comingSoonTeaserScale = 0.88
            comingSoonTeaserOpacity = 0
            withAnimation(.easeInOut(duration: 0.35)) {
                chapter1EndingPhase = .comingSoonTeaser
            }

            try? await Task.sleep(for: .milliseconds(80))
            guard run == chapter1EndingRunID else { return }
            withAnimation(.spring(response: 0.52, dampingFraction: 0.82)) {
                comingSoonTeaserScale = 1.0
                comingSoonTeaserOpacity = 1.0
            }

            try? await Task.sleep(for: chapter1EndTeaserHold)
            guard run == chapter1EndingRunID else { return }

            withAnimation(.easeInOut(duration: 0.55)) {
                chapter1EndingPhase = .finished
                comingSoonTeaserOpacity = 0
                comingSoonTeaserScale = 0.94
            }

            chapter1EndingSequenceLock = false
        }
    }

    private func cancelChapter1EndingSequence(resetPhase: Bool) {
        chapter1EndingRunID += 1
        chapter1EndingSequenceLock = false
        if resetPhase {
            withAnimation(.easeOut(duration: 0.25)) {
                chapter1EndingPhase = .idle
            }
            comingSoonTeaserScale = 0.88
            comingSoonTeaserOpacity = 0
        }
    }

    // MARK: Helpers

    private func resumeAmbientEffectsIfNeeded() {
        guard !gameManager.messages.isEmpty else { return }

        let heartbeatScenes = ["S7", "S8"]
        if heartbeatScenes.contains(gameManager.currentScene) {
            gameManager.startHeartbeat()
        }
    }

    private func actTitleName(for act: Int) -> String {
        switch act {
        case 2:  "The File"
        case 3:  "Resolution"
        default: "First Contact"
        }
    }
}
