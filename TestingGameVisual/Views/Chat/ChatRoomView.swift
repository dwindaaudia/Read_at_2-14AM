import SwiftUI

// MARK: - Chat Room View
// ─────────────────────────────────────────────────────────────────────────────

struct ChatRoomView: View {
    @ObservedObject var gameManager: GameManager
    let onReturnToMenu: () -> Void
    
    @State private var showChoices       = false
    @State private var showTutorial      = false
    @State private var showActTransition = false
    @State private var transitionActNumber  = 2
    @State private var shownActTransitions  = Set<Int>()
    
    private var alexStatusText: String {
        switch gameManager.currentScene {
        case "ENDING":          return "Connection lost"
        case "S1", "S2", "S3": return "Active 5 years ago"
        default:
            if gameManager.denialScore > 10 { return "Signal corrupted…" }
            return "Active now"
        }
    }
    
    private var headerAvatarColor: Color {
        if gameManager.denialScore >= 12 { return .red    }
        if gameManager.denialScore >=  7 { return .orange }
        if gameManager.denialScore <= -7 { return .blue   }
        return .gray
    }
    
    var body: some View {
        VStack(spacing: 0) {
            
            FakeStatusBarView(
                time:         gameManager.fakeTime,
                batteryLevel: gameManager.fakeBatteryLevel,
                denialScore:  gameManager.denialScore
            )
            .background(Color.black.ignoresSafeArea(.all, edges: .top))
            .zIndex(100)
            
            NavigationStack {
                ZStack(alignment: .bottom) {
                    Color.black.ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        
                        // ── 1. DEBUG BAR ─────────────────────────────────────
                        if AppSettings.shared.debugBarVisible && gameManager.currentScene != "ENDING" {
                            DebugStatusView(
                                denialScore:  gameManager.denialScore,
                                currentAct:   gameManager.currentAct,
                                currentScene: gameManager.currentScene,
                                modelStatus:  gameManager.modelStatusText
                            )
                            .padding(.horizontal)
                            .padding(.top, 12)
                        }
                        
                        // ── 2. CHAT SCROLL AREA ──────────────────────────────
                        ScrollView {
                            ScrollViewReader { proxy in
                                VStack(spacing: 12) {
                                    
                                    ForEach(gameManager.messages) { message in
                                        MessageBubbleEnhanced(
                                            message: message,
                                            useTypewriter: message == gameManager.messages.last && !message.isFromMe
                                        )
                                        .id(message.id)
                                    }
                                    
                                    if gameManager.isTyping {
                                        AlexTypingIndicatorView(
                                            psycheLevel: gameManager.currentPsycheLevel,
                                            denialScore: gameManager.denialScore
                                        )
                                        .id("TypingIndicator")
                                    }
                                    
                                    // ── 3. ENDING SECTION ────────────────────
                                    if gameManager.currentScene == "ENDING" && gameManager.isEndingFinished {
                                        CinematicEndingView(
                                            gameManager: gameManager,
                                            onPlayAgain: {
                                                gameManager.restartGame()
                                                GameSaveManager.shared.clearSave()
                                            },
                                            onReturnToMenu: {
                                                GameSaveManager.shared.clearSave()
                                                onReturnToMenu()
                                            },
                                            onShare: nil
                                        )
                                        .transition(.opacity)
                                        .zIndex(100)
                                    }
                                    
                                    Color.clear.frame(height: 1).id("bottomAnchor")
                                }
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
                        .padding(.top, 12)
                        
                        // ── 4. INPUT BAR ─────────────────────────────────────
                        if gameManager.currentScene != "ENDING" {
                            HStack(spacing: 12) {
                                HStack {
                                    Text(gameManager.currentChoices.isEmpty
                                         ? "Waiting for Alex…"
                                         : "Choose a response…")
                                    .foregroundColor(.gray)
                                    .font(.body)
                                    Spacer()
                                    Image(systemName: "face.smiling").foregroundColor(.gray)
                                }
                                .padding(.horizontal, 16).padding(.vertical, 8)
                                .background(Color(UIColor.systemGray6))
                                .cornerRadius(20)
                                .onTapGesture {
                                    if !gameManager.currentChoices.isEmpty {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                            showChoices.toggle()
                                        }
                                    }
                                }
                                
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(showChoices ? .red : .gray)
                            }
                            .padding(.horizontal).padding(.vertical, 10)
                            .background(.ultraThinMaterial)
                        }
                        
                        // ── 5. CHOICE KEYBOARD ───────────────────────────────
                        if showChoices && !gameManager.currentChoices.isEmpty {
                            ChoiceKeyboardView(
                                choices:     gameManager.currentChoices,
                                denialScore: gameManager.denialScore
                            ) { choice in
                                withAnimation {
                                    showChoices = false
                                    gameManager.playerMadeChoice(choice)
                                }
                            }
                            .transition(.move(edge: .bottom))
                            .zIndex(2)
                        }
                    }
                    
                    // ── 6. MEMORY BLEED OVERLAY ──────────────────────────────
                    MemoryBleedOverlayView(
                        denialScore:         gameManager.denialScore,
                        recentAlexMessages:  gameManager.recentAlexReplies
                    )
                    .allowsHitTesting(false)
                    .zIndex(5)
                    
                    // ── 7. GLITCH OVERLAY ────────────────────────────────────
                    GlitchSceneView(
                        trigger:       gameManager.glitchTrigger,
                        level:         gameManager.denialLevel,
                        denialScore:   gameManager.denialScore,
                        shadowTrigger: gameManager.shadowTrigger,
                        crackTrigger:  gameManager.crackTrigger
                    )
                    .allowsHitTesting(false)
                    
                    // ── 8. TUTORIAL OVERLAY ──────────────────────────────────
                    if showTutorial {
                        TutorialOverlayView(isVisible: $showTutorial)
                            .transition(.opacity)
                            .zIndex(90)
                    }
                    
                    // ── 9. ACT TRANSITION OVERLAY ────────────────────────────
                    if showActTransition {
                        ActTransitionView(
                            actNumber: transitionActNumber,
                            actTitle:  actTitleName(for: transitionActNumber),
                            isVisible: $showActTransition
                        )
                        .transition(.opacity)
                        .zIndex(80)
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        VStack(spacing: 1) {
                            Image(systemName: "person.crop.circle.fill")
                                .foregroundColor(headerAvatarColor)
                                .font(.system(size: 20))
                            Text("Alex")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                            Text(alexStatusText)
                                .font(.system(size: 9))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    ToolbarItem(placement: .topBarTrailing) {
                        HStack(spacing: 12) {
                            UnknownContactButton()
                            EvidenceBoardButton()
                            SignalBarView(denialScore: gameManager.denialScore)
                        }
                        .padding(.trailing, 2)
                    }
                }
                .onAppear {
                    if !AppSettings.shared.hasSeenTutorial {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation(.easeIn(duration: 0.4)) { showTutorial = true }
                        }
                    }
                    resumeAmbientEffectsIfNeeded()
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
            }
        }
        .checkRealTimeEvent(manager: gameManager)
        .statusBarHidden(true)
    }
    
    // MARK: - Resume Ambient Effects (used on Continue)
    /// Restores heartbeat and noise overlay when resuming a saved game,
    /// without requiring new player input.
    private func resumeAmbientEffectsIfNeeded() {
        guard !gameManager.messages.isEmpty else { return }
        
        // Heartbeat is active during Scene7 and Scene8
        let heartbeatScenes = ["S7", "S8"]
        if heartbeatScenes.contains(gameManager.currentScene) {
            gameManager.startHeartbeat()
        }
        // GlitchSceneView handles noise sync via .onAppear using restored denialScore
    }
    
    // MARK: - Helpers
    
    private func actTitleName(for act: Int) -> String {
        switch act {
        case 2:  "The File"
        case 3:  "Resolution"
        default: "First Contact"
        }
    }
    
    // MARK: - Nested: Psychological Profile Card
    
    struct PsychologicalProfileView: View {
        let profile: (title: String, description: String, color: Color)
        
        var body: some View {
            VStack(spacing: 20) {
                Text("SESSION TERMINATED")
                    .font(.caption.monospaced())
                    .foregroundColor(.gray)
                
                Text(profile.title)
                    .font(.system(size: 32, weight: .black))
                    .foregroundColor(profile.color)
                
                Text(profile.description)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Divider().background(Color.white.opacity(0.2))
                
                Text("DATA LOG: 18 OCT 2019 - 02:14 AM")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .padding(24)
            .background(Color.white.opacity(0.05))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(profile.color.opacity(0.5), lineWidth: 2)
            )
            .shadow(color: profile.color.opacity(0.2), radius: 15)
        }
    }
}
