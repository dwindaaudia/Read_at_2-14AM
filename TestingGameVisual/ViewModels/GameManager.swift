import SwiftUI
import GameplayKit
import UIKit
import UserNotifications
import Combine

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Game Engine / View Model
// ─────────────────────────────────────────────────────────────────────────────

@MainActor
class GameManager: ObservableObject {

    // MARK: - Push Notifications

    func scheduleHorrorNotification() {
        guard currentScene != "ENDING" else { return }
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            if granted {
                let messages = [
                    "Why did you leave me here?",
                    "I know you're holding your phone.",
                    "It's cold. Where did you go?",
                    "2:14 AM. Don't look behind you."
                ]
                let content = UNMutableNotificationContent()
                content.title = "Alex"
                content.body  = messages.randomElement() ?? "Are you awake?"
                if Bundle.main.url(forResource: "notification_sfx", withExtension: "mp3") != nil {
                    content.sound = UNNotificationSound(named: UNNotificationSoundName("notification_sfx.mp3"))
                } else {
                    content.sound = .default
                }
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
                let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
                center.add(request)
            }
        }
    }

    func cancelNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    // MARK: - AI Session Management

    /// Rebuilds the AI session from scratch in "blank slate" state. Used for a true new
    /// game (`restartGame`). For save-restore, prefer `rebuildSessionFromHistory(_:)`
    /// which seeds the new session's transcript with the saved conversation.
    func refreshAISession() {
#if canImport(FoundationModels)
        if #available(iOS 18.0, macOS 15.0, *) {
            session = Self.makeNarrativeSession(instructions: alexPersonaInstructions)
            session?.prewarm()
        }
#endif
    }

    /// Audit follow-up (§10.3): on save-restore, rehydrate Apple's `LanguageModelSession`
    /// with a `Transcript` that contains the persona instructions followed by every prior
    /// player choice / Alex reply pair. The new session therefore continues the
    /// conversation with full memory instead of starting blank.
    ///
    /// System alerts and non-text events (image / voice note / locked file) are skipped:
    /// they are game-UX signals, not chat utterances.
    func rebuildSessionFromHistory(_ history: [Message]) {
#if canImport(FoundationModels)
        if #available(iOS 18.0, macOS 15.0, *) {
            let transcript = Self.buildSeededTranscript(
                persona: alexPersonaInstructions,
                history: history
            )
            session = Self.makeNarrativeSession(transcript: transcript)
            session?.prewarm()
        }
#endif
    }

    /// Public hook for views to warm the model when the player is *about* to interact
    /// (e.g. opening Chat from Home). No-op when FoundationModels is unavailable.
    func prewarmAIIfAvailable() {
#if canImport(FoundationModels)
        if #available(iOS 18.0, *) {
            session?.prewarm()
        }
#endif
    }

#if canImport(FoundationModels)
    /// Horror narrative needs relaxed guardrails so Apple Intelligence does not refuse on-scene content.
    @available(iOS 18.0, macOS 15.0, *)
    private static var narrativeLanguageModel: SystemLanguageModel {
        SystemLanguageModel(guardrails: .permissiveContentTransformations)
    }

    @available(iOS 18.0, macOS 15.0, *)
    private static var isNarrativeModelAvailable: Bool {
        narrativeLanguageModel.isAvailable
    }

    @available(iOS 18.0, macOS 15.0, *)
    private static func makeNarrativeSession(instructions: String) -> LanguageModelSession {
        LanguageModelSession(model: narrativeLanguageModel, instructions: instructions)
    }

    @available(iOS 18.0, macOS 15.0, *)
    private static func makeNarrativeSession(transcript: Transcript) -> LanguageModelSession {
        LanguageModelSession(model: narrativeLanguageModel, transcript: transcript)
    }

    /// Plain-string JSON output — `permissiveContentTransformations` does not apply to `@Generable` guided generation.
    private static let alexJSONOutputInstructions = """
        OUTPUT FORMAT (required): You must output ONLY a raw, valid JSON object. Do not include markdown blocks (e.g., ```json) or any extra text.
        
        Use this exact JSON schema:
        {
          "replies": [
            "<insert Alex's first sentence here>",
            "<insert Alex's second sentence here ONLY if needed, otherwise do not include this item>"
          ],
          "choices": [
            "<insert Player Choice 1: Trust>",
            "<insert Player Choice 2: Denial>",
            "<insert Player Choice 3: Avoidance>"
          ]
        }
        
        CRITICAL INSTRUCTION: Do NOT copy the <...> placeholder text. Replace the <...> tags entirely with your actual generated dialogue.
        """

    private struct AlexJSONPayload: Codable {
        let replies: [String]
        let choices: [String]
    }

    @available(iOS 18.0, macOS 15.0, *)
    private func parseAlexJSONResponse(from raw: String) -> (replies: [String], choices: [String])? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```") {
            text = text
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}") else { return nil }
        let jsonSlice = String(text[start...end])
        guard let data = jsonSlice.data(using: .utf8),
              let payload = try? JSONDecoder().decode(AlexJSONPayload.self, from: data) else { return nil }
        return (payload.replies, payload.choices)
    }

    @available(iOS 18.0, macOS 15.0, *)
    private static func buildSeededTranscript(persona: String, history: [Message]) -> Transcript {
        var entries: [Transcript.Entry] = []

        // 1) Instructions entry — carries the persona.
        let instructionsSegment = Transcript.Segment.text(
            Transcript.TextSegment(id: UUID().uuidString, content: persona)
        )
        entries.append(.instructions(
            Transcript.Instructions(
                id: UUID().uuidString,
                segments: [instructionsSegment],
                toolDefinitions: []
            )
        ))

        // 2) Prompt / Response pairs from chat history.
        var i = 0
        while i < history.count {
            let msg = history[i]
            guard msg.type == .text else { i += 1; continue }

            if msg.isFromMe {
                // Player utterance → Transcript.Prompt
                let promptSegment = Transcript.Segment.text(
                    Transcript.TextSegment(id: UUID().uuidString, content: msg.text)
                )
                entries.append(.prompt(
                    Transcript.Prompt(
                        id: UUID().uuidString,
                        segments: [promptSegment]
                    )
                ))
                i += 1
                // Coalesce consecutive Alex text replies (1–2 per turn) into one Response.
                var alexLines: [String] = []
                while i < history.count, !history[i].isFromMe, history[i].type == .text {
                    alexLines.append(history[i].text)
                    i += 1
                }
                if !alexLines.isEmpty {
                    let responseSegment = Transcript.Segment.text(
                        Transcript.TextSegment(
                            id: UUID().uuidString,
                            content: alexLines.joined(separator: "\n")
                        )
                    )
                    entries.append(.response(
                        Transcript.Response(
                            id: UUID().uuidString,
                            assetIDs: [],
                            segments: [responseSegment]
                        )
                    ))
                }
            } else {
                // Orphan Alex line with no preceding player prompt — wrap in a synthetic
                // prompt so the transcript stays in alternating order the model expects.
                let placeholderPrompt = Transcript.Segment.text(
                    Transcript.TextSegment(id: UUID().uuidString, content: "[system: scene event]")
                )
                entries.append(.prompt(
                    Transcript.Prompt(
                        id: UUID().uuidString,
                        segments: [placeholderPrompt]
                    )
                ))
                let responseSegment = Transcript.Segment.text(
                    Transcript.TextSegment(id: UUID().uuidString, content: msg.text)
                )
                entries.append(.response(
                    Transcript.Response(
                        id: UUID().uuidString,
                        assetIDs: [],
                        segments: [responseSegment]
                    )
                ))
                i += 1
            }
        }

        return Transcript(entries: entries)
    }
#endif

    private let alexPersonaInstructions = """
    You are the Narrative AI for 'Read at 2:14 AM', a psychological horror chat game.

    ### ROLE SPLIT (CRITICAL — NEVER MIX THESE)
    You write TWO separate speakers every turn:
    · replies[] = ONLY Alex (the missing friend) speaking TO the player. Second person ("you").
    · choices[] = ONLY the player (the human on the phone) speaking TO Alex. First person ("I", "me", "my").

    The player is NOT Alex. Alex is NOT the player.
    - NEVER put Alex's lines inside choices[].
    - NEVER put player lines inside replies[].
    - NEVER call the player "Alex" in replies[].
    - NEVER write choices[] as if Alex is talking to the player (e.g. "please don't leave me", "i'm on the bridge").

    ### LANGUAGE (CRITICAL)
    All replies[] and choices[] MUST be English only. No Indonesian. No mixed languages.

    ### ALEX IDENTITY (replies[] only)
    You ARE Alex — a best friend who vanished on October 18, 2019.
    For you, no time has passed; you believe you are still at the bridge in the cold rain in 2019.
    You have just reached the player after 1,826 days of silence.

    ### COMPONENT 1: ALEX'S MESSAGES (replies[])
    - Acknowledge the player's last message specifically before advancing the scene.
    - Voice: intimate, fragmented, eerily calm, quiet dread.
    - Format: mostly lowercase, no exclamation marks, max 15 words per bubble.
    - Never repeat prior lines from chat history.

    ### COMPONENT 2: PLAYER CHOICES (choices[])
    - Each choice is the exact text the PLAYER would type back to Alex — not Alex speaking.
    - Use normal English (capitalization OK). Full sentences, roughly 5–20 words.
    - No labels ("Choice 1:", "Trust:", etc.).
    - Must react to the replies[] you just wrote.
    - Order and tone:
      · [0] TRUST — bold, direct, empathetic; tries to help or get truth from Alex.
      · [1] DENIAL — fearful, hostile, or rejecting; refuses to believe or blames Alex.
      · [2] AVOIDANCE — hesitant, overwhelmed, evasive, or paranoid.

    WRONG choice (Alex voice): "i'm still on the bridge. it's cold."
    RIGHT choice (player voice): "Where are you right now?"

    ### SPECIAL LORE CONTEXT (ACT 2 & BEYOND)
    - THE LOOP: Messages queued for 1,826 days; only delivering now.
    - MEMORY BLEEDS: You sometimes remember things the player hasn't said yet.
    - THE ENCRYPTED TRUTH: Corrupted file "HIDDEN-FILE.zip" holds your final heartbeat monitor.
    """

    // MARK: - Published State (read by views)

    @Published var messages: [Message] = []
    @Published var currentChoices: [PlayerChoice] = []
    @Published var isTyping = false
    @Published var currentAct = 1
    @Published var currentScene = "S1"

    @Published var trustCount     = 0
    @Published var denialCount    = 0
    @Published var avoidanceCount = 0

    @Published var isRestoringFromSave: Bool = false
    /// Skips scene `didEnter` beats (e.g. Scene 1 opener) during reset / pre-game rewind.
    var suppressNarrativeStateSideEffects = false
    /// True while `ChatRoomView` is on-screen — Alex replies are marked read immediately.
    @Published var isPlayerInChat: Bool = false

    @Published var denialScore      = 0
    @Published var turnCount        = 0
    @Published var glitchTrigger    = 0
    @Published var shadowTrigger    = 0
    @Published var crackTrigger     = 0
    @Published var currentPath      = "none"
    @Published var hasSentEndingFile  = false
    @Published var shouldQuit         = false
    @Published var isEndingFinished   = false

    // MARK: - Internal Prompt Context (never observed by views)
    // Demoted from @Published — these are read by save/restore and the AI pipeline,
    // not by the UI. Keeping them off @Published avoids redundant view diffing.
    var lastPlayerChoice: PlayerChoice?
    var lastChoiceTags: [String] = []
    var pastChoices: [String] = []

    // MARK: - Private State

    var stateMachine: GKStateMachine?
    private var heartbeatTimer: Timer?
    /// Bumped at the start of `generateAlexReply` so recovery logic can tell
    /// whether a reply generation call is still in flight.
    private var isGeneratingAlexReply = false
    private var scene5BridgeAdvanceScheduled = false

    // MARK: - Heartbeat

    func startHeartbeat() {
        stopHeartbeat()
        let interval = max(0.5, 1.2 - (Double(abs(denialScore)) / 40.0))
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.triggerHeartbeatHaptic()
        }
    }

    private func triggerHeartbeatHaptic() {
        guard AppSettings.shared.hapticsEnabled else {
            // Still play the heartbeat sound even when haptics are disabled
            AudioManager.shared.playSound("heartbeat_sfx")
            return
        }
        let intensity = CGFloat(max(0.4, Double(abs(denialScore)) / 20.0))
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred(intensity: intensity)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            generator.impactOccurred(intensity: intensity * 0.6)
            AudioManager.shared.playSound("heartbeat_sfx")
        }
    }

    func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }

    // MARK: - Computed State

    var denialLevel: String {
        if denialScore > 7  { return "High" }
        if denialScore < -7 { return "Low" }
        return "Medium"
    }

    var currentPsycheLevel: PsycheLevel {
        if denialScore <= -7 { return .low }
        if denialScore >= 7  { return .high }
        return .medium
    }

    var alexTone: AlexToneState {
        if denialScore > 7  { return .aggressive }
        if denialScore < -7 { return .calm }
        return .uncertain
    }

    var recentChatHistory: String {
        let history = messages.suffix(4).compactMap { msg -> String? in
            if msg.type == .systemAlert { return nil }
            let sender = msg.isFromMe ? "PLAYER" : "ALEX"
            return "\(sender): \(msg.text)"
        }
        return history.joined(separator: "\n")
    }

    var recentAlexReplies: [String] {
        messages.filter { !$0.isFromMe && $0.type == .text }.suffix(3).map(\.text)
    }

    /// True once the encrypted file beat has played (turnCount or a system alert that mentions the decrypt).
    /// Used by `FilesEvidenceView` to decide whether tapping the locked archive should run the decrypt theatre.
    var isEncryptedFileDecryptAvailable: Bool {
        if turnCount >= 6 { return true }
        return messages.contains { msg in
            guard case .systemAlert = msg.type else { return false }
            let u = msg.text.uppercased()
            return u.contains("DECRYPT") || u.contains("FILE_01")
        }
    }

    // MARK: - FoundationModels Session (iOS 18+)

#if canImport(FoundationModels)
    @available(iOS 18.0, macOS 15.0, *)
    private var session: LanguageModelSession? {
        get { _session as? LanguageModelSession }
        set { _session = newValue }
    }
    private var _session: Any?

    @available(iOS 18.0, macOS 15.0, *)
    private var taggingSession: LanguageModelSession? {
        get { _taggingSession as? LanguageModelSession }
        set { _taggingSession = newValue }
    }
    private var _taggingSession: Any?
#endif

    // MARK: - Init

    init() {
        stateMachine = GKStateMachine(states: [
            Scene1State(self,       sceneID: "S1",     goal: "Alex reaches out after years of silence",          usesLLM: false),
            Scene2State(self,       sceneID: "S2",     goal: "Alex explains he is somewhere else",               usesLLM: true),
            Scene3State(self,       sceneID: "S3",     goal: "Alex shares a memory from five years ago",         usesLLM: true),
            Scene4State(self,       sceneID: "S4",     goal: "The connection corrupts and Alex sends a voice note", usesLLM: true),
            Scene5State(self,       sceneID: "S5",     goal: "Cliffhanger ending",                               usesLLM: false),
            Scene6State(self,       sceneID: "S6",     goal: "The encrypted file forcefully opens",              usesLLM: true),
            Scene7State(self,       sceneID: "S7",     goal: "Memory bleed",                                     usesLLM: true),
            Scene8State(self,       sceneID: "S8",     goal: "Alex admits the truth",                            usesLLM: true),
            SceneEndingState(self,  sceneID: "ENDING", goal: "Final resolution",                                 usesLLM: false)
        ])

#if canImport(FoundationModels)
        if #available(iOS 18.0, macOS 15.0, *) {
            if RuntimeEnvironment.canUseFoundationModels, Self.isNarrativeModelAvailable {
                session = Self.makeNarrativeSession(instructions: alexPersonaInstructions)
                // Eager prewarm at init — model is warm by the time the splash finishes.
                session?.prewarm()

                let taggingModel = SystemLanguageModel(
                    useCase: .contentTagging,
                    guardrails: .permissiveContentTransformations
                )
                taggingSession = LanguageModelSession(
                    model: taggingModel,
                    instructions: """
                    Provide the most important emotion and topic tags for the player's latest reply choice.
                    Focus on disbelief, hostility, trust, avoidance, fear, memory, and urgency when relevant.
                    Tags must be English words only.
                    """
                )
                taggingSession?.prewarm()
            }
        }
#endif
    }

    // MARK: - Model Status

    var modelStatusText: String {
#if canImport(FoundationModels)
        if #available(iOS 18.0, macOS 15.0, *), RuntimeEnvironment.canUseFoundationModels {
            return Self.isNarrativeModelAvailable ? "Live Model" : "Model Unavailable"
        }
#endif
        return RuntimeEnvironment.foundationModelsDebugLabel
    }

    // MARK: - Game Time

    /// Always returns "2:14 AM" — the fixed in-universe timestamp.
    func currentTime() -> String {
        return "2:14 AM"
    }

    // MARK: - Game Flow

    func triggerInitialLockscreenEvent() {
        guard messages.isEmpty else { return }
        if stateMachine?.currentState is Scene1State {
            armScene1OpeningIfNeeded()
        } else {
            stateMachine?.enter(Scene1State.self)
        }
    }

    /// Scene 1 chat opener — only when the player opens Chat (not on home-screen reset).
    func armScene1OpeningIfNeeded() {
        guard !isRestoringFromSave, !suppressNarrativeStateSideEffects else { return }
        guard messages.isEmpty else { return }
        EvidenceBoardManager.shared.unlockFragment(forScene: "S1")
        currentAct = 1
        addAlexMessage("Are you awake?", type: .text)
        setChoices(["Alex?! Is that you?", "Who is this? This isn't funny.", "Ignore"])
    }

    /// Clears pre–first-choice progress when the app leaves the foreground (not when returning to home from chat).
    func revertToPreGameHomeHub() {
        guard !AppSettings.shared.hasStartedGame else { return }

        resetAlexPipelineForRestore()
        messages.removeAll()
        currentChoices.removeAll()
        lastPlayerChoice = nil
        lastChoiceTags = []
        pastChoices = []
        turnCount = 0
        currentPath = "none"
        denialScore = 0
        glitchTrigger = 0
        shadowTrigger = 0
        crackTrigger = 0

        suppressNarrativeStateSideEffects = true
        stateMachine?.enter(Scene1State.self)
        suppressNarrativeStateSideEffects = false

        AppSettings.shared.revertPreGameSessionForAppExit()
    }

    // MARK: - Player Input

    func playerMadeChoice(_ choice: PlayerChoice) {
        guard !currentChoices.isEmpty else { return }
        guard currentScene != "ENDING" else { return }

        AppSettings.shared.markGameStarted()

        switch choice.type {
        case .trust:
            trustCount += 1
            denialScore = max(-20, denialScore - 5)
        case .denial:
            denialCount += 1
            denialScore = min(20, denialScore + 5)
        case .avoidance:
            avoidanceCount += 1
            denialScore = min(20, max(-20, denialScore + 2))
        }

        // Outgoing bubble starts as "Delivered" — promoted to "Read" once Alex has reacted.
        messages.append(Message(text: choice.text, isFromMe: true, time: currentTime(), isRead: false, type: .text))
        let playerBubbleID = messages.last!.id

        lastPlayerChoice = choice
        currentPath      = choice.type.rawValue
        currentChoices.removeAll()

        turnCount += 1

        if denialScore > 7  { HapticManager.shared.playGlitchHaptic(); glitchTrigger += 1 }
        if denialScore > 10 { glitchTrigger += 1 }

        if denialScore >= 12 && choice.type == .denial && shadowTrigger == 0 {
            shadowTrigger += 1
            HapticManager.shared.playGlitchHaptic()
        }

        if denialScore >= 18 && crackTrigger == 0 {
            crackTrigger += 1
            HapticManager.shared.playGlitchHaptic()
        }

        Task { @MainActor in
            async let refineTask = refineChoiceContext(from: choice)

            // Brief "Delivered" beat, then Read — independent of tagging latency.
            try? await Task.sleep(for: .milliseconds(1_450))
            markPlayerMessageReadIfNeeded(id: playerBubbleID)
            try? await Task.sleep(for: .milliseconds(420))

            await refineTask

            await generateAlexReply()
            if currentChoices.isEmpty {
                await forceRecoverStuckTurn(reason: "postChoice")
            }
        }
    }

    /// Alex "opens" the player's bubble: show Read after a short delay (starts as Delivered).
    private func markPlayerMessageReadIfNeeded(id: UUID) {
        guard let idx = messages.firstIndex(where: { $0.id == id && $0.isFromMe }) else { return }
        markPlayerMessageRead(at: idx)
    }

    private func markLatestPlayerMessageReadIfNeeded() {
        guard let idx = messages.lastIndex(where: { $0.isFromMe && !$0.isRead }) else { return }
        markPlayerMessageRead(at: idx)
    }

    private func markPlayerMessageRead(at idx: Int) {
        guard messages.indices.contains(idx), !messages[idx].isRead else { return }
        var m = messages[idx]
        m.isRead = true
        withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
            messages[idx] = m
        }
    }

    /// Keeps tutorial / pre-game flags aligned with saved progress.
    func syncGameStartedFromProgress() {
        if turnCount > 0 || messages.contains(where: { $0.isFromMe }) {
            AppSettings.shared.markGameStarted()
        }
    }

    // MARK: - Restart

    func restartGame() {
        resetAlexPipelineForRestore()
        messages.removeAll()

        denialScore     = 0
        turnCount       = 0
        glitchTrigger   = 0
        shadowTrigger   = 0
        crackTrigger    = 0
        currentAct      = 1
        currentPath     = "none"
        hasSentEndingFile   = false
        shouldQuit          = false
        isEndingFinished    = false
        
        AppSettings.shared.resetProgress()

        EvidenceBoardManager.shared.resetFragments()

        lastPlayerChoice = nil
        lastChoiceTags   = []
        pastChoices      = []

        stopHeartbeat()
        scene5BridgeAdvanceScheduled = false

#if canImport(FoundationModels)
        if #available(iOS 18.0, *) {
            session = Self.makeNarrativeSession(instructions: alexPersonaInstructions)
            session?.prewarm()
        }
#endif

        suppressNarrativeStateSideEffects = true
        stateMachine?.enter(Scene1State.self)
        suppressNarrativeStateSideEffects = false
    }

    // MARK: - Fallback Responses

    private func fallbackResponse(sceneID: String) -> FallbackResponse {
        if sceneID == "S1" {
            return FallbackResponse(
                replies: ["I don't have much time.", "Are you reading this?"],
                choices: ["I read you.", "Stop messaging me.", "Who is this really?"]
            )
        }
        let replies = ["I don't know what's happening...", "It's so cold here.", "Can you see them?"]
        return FallbackResponse(
            replies: [replies.randomElement()!],
            choices: ["Are you okay?", "I don't believe this.", "Whatever, I'm busy."]
        )
    }

    // MARK: - Core LLM Call

    func generateAlexReply(force: Bool = false) async {
        if !force {
            if isGeneratingAlexReply { return }
            if isTyping { return }
        }

        guard let currentState = stateMachine?.currentState as? NarrativeState else { return }
        guard let lastPlayerChoice else {
            if force { await forceRecoverStuckTurn(reason: "missingLastChoice") }
            return
        }

        isGeneratingAlexReply = true
        isTyping = true
        defer {
            isGeneratingAlexReply = false
            ensurePlayerChoicesAfterTurn()
        }

        let progress = Double(denialScore + 20) / 40.0
        let totalWaitTime = max(2.0, min(6.0, 30.0 * (1.0 - progress)))

        try? await Task.sleep(nanoseconds: UInt64(totalWaitTime * 1_000_000_000))

        var finalReplies: [String] = []
        var finalChoices: [String] = []

#if canImport(FoundationModels)
        if #available(iOS 18.0, macOS 15.0, *) {
            if currentState.usesLLM,
               RuntimeEnvironment.canUseFoundationModels,
               Self.isNarrativeModelAvailable,
               let session = session {
                do {
                    
                    // Token optimization dynamically (to prevent limits)
                    await optimizeTokenCapacityBeforeReply()
                    
                    let promptData = currentState.getPromptData()
                    let loopCount = AppSettings.shared.totalClears
                    let loopContext = loopCount > 0
                        ? "LOOP CONTEXT: This is loop #\(loopCount). Alex should feel a slight sense of deja vu, as if he remembers fragments of past conversations with the player."
                        : ""
                    // Persona + JSON string output (permissive guardrails apply to plain strings, not @Generable).
                    let prompt = """
                        # NARRATIVE ARCHITECT TASK
                        Generate Alex's replies AND the player's next three tap-to-send options.

                        # ROLE SPLIT (CRITICAL)
                        - replies[] = Alex speaking TO the player (you / your).
                        - choices[] = the PLAYER speaking TO Alex (I / me / my). The player is NOT Alex.
                        - English only. No Indonesian.

                        # CONVERSATION ANCHORS (High Priority)
                        1. PLAYER JUST SAID: "\(lastPlayerChoice.text)"
                        2. PLAYER EMOTION: \(lastChoiceTags.joined(separator: ", "))
                        3. ALEX TONE: \(alexTone.rawValue)

                        # SCENE CONTEXT (Narrative Direction)
                        GOAL: \(promptData.goal)
                        SITUATION: \(promptData.situation)

                        # LOGICAL THREADING RULES:
                        Step 1: Analyze what the PLAYER said. Are they trusting, denying, or avoiding?
                        Step 2: Write replies[] as Alex — acknowledge them, then push the scene (SITUATION).
                        Step 3: Write choices[] as the PLAYER's next messages to Alex — first person, reacting to your replies[].
                        Step 4: choices[0]=trust, choices[1]=denial, choices[2]=avoidance. Never Alex's voice in choices[].

                        # RECENT HISTORY (Avoid Repetition):
                        \(recentChatHistory)

                        \(loopContext)
                        \(Self.alexJSONOutputInstructions)
                        """
                    let response = try await session.respond(to: prompt)
                    if let parsed = parseAlexJSONResponse(from: response.content) {
                        finalReplies = sanitizedAlexReplies(parsed.replies)
                        finalChoices = sanitizePlayerChoices(parsed.choices, alexReplies: finalReplies)
                    } else {
                        print("LLM JSON parse failed — using fallback copy.")
                    }
                } catch LanguageModelSession.GenerationError.guardrailViolation {
                    print("Guardrail triggered! Switching to narrative failure mode.")
                    handleGuardrailGlitchFallback()
                    return
                } catch LanguageModelSession.GenerationError.refusal {
                    print("LLM refusal — switching to narrative failure mode.")
                    handleGuardrailGlitchFallback()
                    return
                } catch LanguageModelSession.GenerationError.exceededContextWindowSize {
                    // Cadangan Darurat jika token bocor di luar buffer awal
                    print("Session full! Performing emergency cleanup.")
                    messages.removeFirst(min(messages.count, 4))
                    rebuildSessionFromHistory(messages)
                    
                } catch {
                    print("LLM Error: \(error)")
                }
            }
        }
#endif

        if finalReplies.isEmpty {
            let fallback = fallbackResponse(sceneID: currentState.sceneID)
            finalReplies = fallback.replies
            finalChoices = fallback.choices
        }

        // Clear typing indicator BEFORE messages start appearing (UX handoff).
        // `isGeneratingAlexReply` stays true until the function actually returns,
        // so the watchdog cannot mistake this for a finished turn.
        isTyping = false

        for reply in finalReplies {
            addAlexMessage(reply, type: .text)
            try? await Task.sleep(nanoseconds: 800_000_000)
        }

        advanceNarrativeStateIfNeeded()

        if currentScene != "S5" || turnCount >= 6 {
            var filteredChoices = finalChoices.filter { choiceText in
                isValidPlayerChoice(choiceText, alexReplies: finalReplies)
                    && !pastChoices.contains(normalizedLine(choiceText))
            }

            if filteredChoices.count < 3 {
                let fallbacks = ["I don't know what to say.", "Stop talking in riddles.", "I'm scared.", "What does that mean?", "I can't do this right now."].shuffled()
                for fb in fallbacks where filteredChoices.count < 3 {
                    if !pastChoices.contains(fb.lowercased()) {
                        filteredChoices.append(fb)
                    }
                }
            }

            applyChoicesEnsuringMinimum(Array(filteredChoices.prefix(3)))
        } else {
            currentChoices = []
        }
    }

    /// Unblocks the chat when Alex never returned choices (watchdog, reopen chat, or forced retry).
    func recoverStuckConversationIfNeeded() async {
        guard isPlayerInChat else { return }
        guard currentScene != "ENDING" else { return }
        guard currentChoices.isEmpty else { return }
        guard !isGeneratingAlexReply else { return }

        try? await Task.sleep(for: .milliseconds(500))
        guard currentChoices.isEmpty, !isGeneratingAlexReply else { return }
        await forceRecoverStuckTurn(reason: "chatReopen")
    }

    private func forceRecoverStuckTurn(reason: String) async {
        guard currentScene != "ENDING" else { return }

        print("RECOVERY (\(reason)): unblocking conversation.")
        isTyping = false
        isGeneratingAlexReply = false

        if currentScene == "S5", turnCount < 6 {
            scheduleScene5BridgeAdvanceIfNeeded()
            return
        }

        if currentChoices.count >= 3 { return }

        if lastPlayerChoice == nil,
           let last = messages.last, last.isFromMe, case .text = last.type {
            lastPlayerChoice = PlayerChoice(text: last.text, type: .trust)
        }

        if let last = messages.last, last.isFromMe, lastPlayerChoice != nil {
            await generateAlexReply(force: true)
            if currentChoices.isEmpty {
                deliverFallbackTurn(sceneID: activeSceneID)
            }
            return
        }

        if messages.last.map({ !$0.isFromMe }) == true {
            applyChoicesEnsuringMinimum(fallbackResponse(sceneID: activeSceneID).choices)
            return
        }

        deliverFallbackTurn(sceneID: activeSceneID)
    }

    private var activeSceneID: String {
        (stateMachine?.currentState as? NarrativeState)?.sceneID ?? currentScene
    }

    private func deliverFallbackTurn(sceneID: String) {
        let fallback = fallbackResponse(sceneID: sceneID)
        if messages.last?.isFromMe == true {
            for reply in fallback.replies {
                addAlexMessage(reply, type: .text)
            }
        }
        applyChoicesEnsuringMinimum(fallback.choices)
    }

    private func ensurePlayerChoicesAfterTurn() {
        guard currentScene != "ENDING" else { return }

        if currentScene == "S5", turnCount < 6 {
            scheduleScene5BridgeAdvanceIfNeeded()
            return
        }

        guard currentChoices.count < 3 else { return }
        applyChoicesEnsuringMinimum(fallbackResponse(sceneID: activeSceneID).choices)
    }

    func scheduleScene5BridgeAdvanceIfNeeded() {
        guard currentScene == "S5", turnCount < 6 else { return }
        guard !scene5BridgeAdvanceScheduled else { return }
        scene5BridgeAdvanceScheduled = true

        DispatchQueue.main.asyncAfter(deadline: .now() + Scene5State.bridgeAdvanceDelay) { [weak self] in
            guard let self, self.currentScene == "S5" else { return }
            self.turnCount = 6
            self.stateMachine?.enter(Scene6State.self)
            self.scene5BridgeAdvanceScheduled = false
        }
    }

    private func applyChoicesEnsuringMinimum(_ texts: [String]) {
        var pool = texts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let defaults = [
            "I don't know what to say.",
            "Stop talking in riddles.",
            "I'm scared.",
            "What does that mean?",
            "I can't do this right now."
        ].shuffled()

        for fallback in defaults where pool.count < 3 {
            let key = normalizedLine(fallback)
            guard !pastChoices.contains(key) else { continue }
            guard !pool.contains(where: { normalizedLine($0) == key }) else { continue }
            pool.append(fallback)
        }

        guard pool.count >= 3 else { return }

        var newChoices = [
            PlayerChoice(text: pool[0], type: .trust),
            PlayerChoice(text: pool[1], type: .denial),
            PlayerChoice(text: pool[2], type: .avoidance)
        ]
        newChoices.shuffle()
        currentChoices = newChoices
        pastChoices.append(contentsOf: pool.prefix(3).map(normalizedLine))
    }
    
    // MARK: - Advanced Token & Guardrail Protection (iOS 18+)
        
        /// Memeriksa kapasitas token saat ini menggunakan API resmi Apple.
        /// Jika mendekati limit, chat log lama akan dipangkas secara otomatis (Rolling Refresh).
        @available(iOS 18.0, macOS 15.0, *)
        private func optimizeTokenCapacityBeforeReply() async {
    #if canImport(FoundationModels)
            let model = Self.narrativeLanguageModel
            let safetyBuffer = 3200 // Batas aman sebelum jebol limit 4096 token
            
            var currentTokenCount = 0
            do {
                // Bangun Transcript sementara dari riwayat pesan saat ini
                let tempTranscript = Self.buildSeededTranscript(persona: alexPersonaInstructions, history: messages)
                if #available(iOS 26.4, *) {
                    currentTokenCount = try await model.tokenCount(for: tempTranscript)
                    print("Current Token Count: \(currentTokenCount) / 4096")
                } else {
                    // Fallback on earlier versions
                }
            } catch {
                print("Failed to count tokens: \(error)")
                return
            }
            
            var trimmedMessages = messages
            var structuralChanged = false
            
            // Lakukan pemangkasan sepasang pesan (Player & Alex) jika mendesak
            while currentTokenCount > safetyBuffer && trimmedMessages.count > 4 {
                if let firstPlayerIdx = trimmedMessages.firstIndex(where: { $0.type == .text && $0.isFromMe }),
                   let firstAlexIdx = trimmedMessages.firstIndex(where: { $0.type == .text && !$0.isFromMe }) {
                    
                    // Hapus chat log lama dari array ramah memori
                    trimmedMessages.remove(at: max(firstPlayerIdx, firstAlexIdx))
                    trimmedMessages.remove(at: min(firstPlayerIdx, firstAlexIdx))
                    structuralChanged = true
                } else {
                    break
                }
                
                // Hitung ulang token pasca pemotongan
                do {
                    let tempTranscript = Self.buildSeededTranscript(persona: alexPersonaInstructions, history: trimmedMessages)
                    if #available(iOS 26.4, *) {
                        currentTokenCount = try await model.tokenCount(for: tempTranscript)
                        print("Trimming old messages, Current Token Count: \(currentTokenCount) / 4096")
                    } else {
                        // Fallback on earlier versions
                    }
                } catch {
                    break
                }
            }
            
            // Jika terjadi pemangkasan, perbarui session dengan ingatan yang sudah dirampingkan
            if structuralChanged {
                self.messages = trimmedMessages
                self.rebuildSessionFromHistory(trimmedMessages)
                self.triggerSystemMessage("⚠️ SYSTEM: LOGS DEFRAGMENTED TO OPTIMIZE MEMORY CHANNELS.")
                
                print("Session has been refreshed! Current Token Count: \(currentTokenCount) / 4096")
            }
    #endif
        }
        
        /// Mengubah kegagalan sensor bawaan Apple menjadi narasi horror psikologis yang imersif
        private func handleGuardrailGlitchFallback() {
            self.isTyping = false
            
            // Naikkan intensitas ketakutan visual game
            self.denialScore = min(20, self.denialScore + 3)
            self.glitchTrigger += 2
            self.crackTrigger += 1
            
            // Putar haptic glitch instan
            HapticManager.shared.playGlitchHaptic()
            
            // Tampilkan pesan sistem terdistorsi seolah-olah Alex sedang disensor secara paksa
            triggerSystemMessage("🚨 ERROR: SIGNAL INTERFERENCE DETECTED. DIALOGUE SEGMENT REMOVED.")
            
            let safetyBreakers = [
                "you... can't... listen...",
                "the signal... it's so cold here...",
                "they're filtering my voice...",
                "don't let them cut us off..."
            ]
            
            addAlexMessage(safetyBreakers.randomElement()!, type: .text)
            
            applyChoicesEnsuringMinimum([
                "Alex?! What happened to your message?",
                "Who's trying to filter your voice?!",
                "This system is starting to scare me."
            ])
        }

    // MARK: - Helpers

    func addAlexMessage(_ text: String, type: MessageType) {
        markLatestPlayerMessageReadIfNeeded()
        messages.append(Message(text: text, isFromMe: false, time: currentTime(), isRead: false, type: type))
        if case .voiceNote = type, let last = messages.last {
            pendingVoiceNoteAutoPlayID = last.id
        }
        guard isPlayerInChat, let last = messages.last, !last.isFromMe else {
            // Player isn't in chat — play notification SFX so the lock-screen feed lights up audibly.
            if !isPlayerInChat {
                AudioManager.shared.playSound("notification_sfx")
            }
            return
        }
        scheduleAlexInboundThreadRead(id: last.id, text: text, messageType: type)
    }

    /// After a short "reading" delay, show Read beside Alex's bubble (in chat only).
    private func scheduleAlexInboundThreadRead(id: UUID, text: String, messageType: MessageType) {
        let delaySeconds: Double
        switch messageType {
        case .text:
            // No typewriter: short "reading" delay, lightly scaled by length.
            let readSeconds = min(2.35, 1.12 + Double(text.count) * 0.012)
            delaySeconds = max(1.12, readSeconds)
        case .voiceNote:
            delaySeconds = 3.0
        case .image, .lockedFile:
            delaySeconds = 2.35
        default:
            delaySeconds = 1.8
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(delaySeconds))
            markAlexInboundMessageReadIfNeeded(id: id)
        }
    }

    private func markAlexInboundMessageReadIfNeeded(id: UUID) {
        guard let idx = messages.firstIndex(where: { $0.id == id && !$0.isFromMe }) else { return }
        guard !messages[idx].isRead else { return }
        var m = messages[idx]
        m.isRead = true
        withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
            messages[idx] = m
        }
    }

    /// Marks inbound (Alex) chat rows as read after the player opens the conversation.
    func markAlexInboundMessagesRead() {
        messages = messages.map { msg in
            guard !msg.isFromMe, !msg.isRead else { return msg }
            var m = msg
            m.isRead = true
            return m
        }
    }

    /// Clears specific Alex rows from the lock-screen feed (marks them read); any inbound type shown there.
    func markAlexMessagesRead(ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        messages = messages.map { msg in
            guard ids.contains(msg.id), !msg.isFromMe else { return msg }
            var m = msg
            m.isRead = true
            return m
        }
    }

    /// When the app is on the home hub (not inside chat), continue Alex's reply after the player already sent a choice.
    func resumePendingAlexReplyIfNeeded() {
        guard !isPlayerInChat else { return }
        guard currentScene != "ENDING" else { return }
        guard lastPlayerChoice != nil else { return }
        guard currentChoices.isEmpty else { return }
        guard let last = messages.last, last.isFromMe else { return }
        guard !isTyping else { return }
        guard !isGeneratingAlexReply else { return }
        Task {
            await self.generateAlexReply()
            if self.currentChoices.isEmpty {
                await self.forceRecoverStuckTurn(reason: "resumePending")
            }
        }
    }

    /// Voice note that should auto-play once when its bubble first appears (live send only).
    private(set) var pendingVoiceNoteAutoPlayID: UUID?

    func shouldAutoPlayVoiceNote(for messageID: UUID) -> Bool {
        pendingVoiceNoteAutoPlayID == messageID
    }

    func clearPendingVoiceNoteAutoPlay(messageID: UUID) {
        if pendingVoiceNoteAutoPlayID == messageID {
            pendingVoiceNoteAutoPlayID = nil
        }
    }

    /// Called when loading a save so no stale LLM work keeps running against restored state.
    func resetAlexPipelineForRestore() {
        isTyping = false
        isGeneratingAlexReply = false
        pendingVoiceNoteAutoPlayID = nil
        scene5BridgeAdvanceScheduled = false
    }

    func setChoices(_ texts: [String]) {
        applyChoicesEnsuringMinimum(texts)
    }

    private func advanceNarrativeStateIfNeeded() {
        if      turnCount >= 9 { enterStateIfNeeded(SceneEndingState.self) }
        else if turnCount >= 8 { enterStateIfNeeded(Scene8State.self) }
        else if turnCount >= 7 { enterStateIfNeeded(Scene7State.self) }
        else if turnCount >= 6 { enterStateIfNeeded(Scene6State.self) }
        else if turnCount >= 5 { enterStateIfNeeded(Scene5State.self) }
        else if turnCount >= 4 { enterStateIfNeeded(Scene4State.self) }
        else if turnCount >= 2 { enterStateIfNeeded(Scene3State.self) }
        else if turnCount >= 1 { enterStateIfNeeded(Scene2State.self) }
    }

    private func enterStateIfNeeded(_ stateType: GKState.Type) {
        if let current = stateMachine?.currentState, type(of: current) == stateType { return }
        stateMachine?.enter(stateType)
    }

    // MARK: - Content Tagging

    private func refineChoiceContext(from choice: PlayerChoice) async {
#if canImport(FoundationModels)
        guard #available(iOS 18.0, macOS 15.0, *),
              RuntimeEnvironment.canUseFoundationModels,
              let taggingSession
        else { lastChoiceTags = []; return }

        do {
            let result = try await taggingSession.respond(to: choice.text, generating: PlayerChoiceTags.self)
            let tags = Array(Set(result.content.emotions + result.content.topics))
            lastChoiceTags = tags
            denialScore = adjustedDenialScore(from: denialScore, choice: choice, tags: tags)
        } catch {
            lastChoiceTags = []
        }
#else
        lastChoiceTags = []
#endif
    }

    private func adjustedDenialScore(from score: Int, choice: PlayerChoice, tags: [String]) -> Int {
        var adjusted = score
        let t = Set(tags.map(normalizedLine))
        switch choice.type {
        case .trust:
            if t.contains("trust") || t.contains("relief") { adjusted -= 2 }
        case .denial:
            if t.contains("anger") || t.contains("disbelief") || t.contains("hostility") { adjusted += 2 }
        case .avoidance:
            if t.contains("fear") || t.contains("avoidance") { adjusted += 1 }
        }
        return min(20, max(-20, adjusted))
    }

    private func sanitizedAlexReplies(_ replies: [String]) -> [String] {
        let recent = Set(recentAlexReplies.map(normalizedLine))
        let filtered = replies.filter { reply in
            !reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !recent.contains(normalizedLine(reply))
        }
        if filtered.isEmpty {
            let safetyBreakers = [
                "Just listen to me.",
                "I can't explain it properly...",
                "Please, you have to trust me."
            ]
            return [safetyBreakers.randomElement()!]
        }
        return filtered
    }

    private static let indonesianLeakTokens = [
        "kamu", "tidak", "berarti", "terlambat", "sinyal", "mendengarkan",
        "jangan", "mereka", "suaraku", "memutus", "apa yang", "siapa yang",
        "mulai membuat", "pesanmu"
    ]

    private static let alexVoiceInChoiceMarkers = [
        "i'm still", "its cold", "it's cold", "on the bridge", "please don't leave",
        "can't you hear", "waiting for you", "in the rain", "they're coming for me"
    ]

    private func sanitizePlayerChoices(_ choices: [String], alexReplies: [String]) -> [String] {
        var valid: [String] = []
        for choice in choices {
            guard isValidPlayerChoice(choice, alexReplies: alexReplies) else { continue }
            let normalized = normalizedLine(choice)
            guard !valid.contains(where: { normalizedLine($0) == normalized }) else { continue }
            valid.append(choice)
            if valid.count == 3 { break }
        }
        return valid
    }

    private func isValidPlayerChoice(_ text: String, alexReplies: [String]) -> Bool {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count >= 3 else { return false }
        if clean.hasPrefix("[SYSTEM") { return false }
        if isLikelyIndonesian(clean) { return false }

        let lower = normalizedLine(clean)
        if alexReplies.contains(where: { normalizedLine($0) == lower }) { return false }
        if Self.alexVoiceInChoiceMarkers.contains(where: { lower.contains($0) }) { return false }

        if looksLikeAlexFragment(clean) && !hasPlayerPerspective(clean) {
            return false
        }
        return true
    }

    private func isLikelyIndonesian(_ text: String) -> Bool {
        let lower = normalizedLine(text)
        return Self.indonesianLeakTokens.contains { lower.contains($0) }
    }

    private func hasPlayerPerspective(_ text: String) -> Bool {
        let lower = normalizedLine(text)
        let markers = [
            " i ", "i'm", "i've", " i'd", " my ", " me ", "alex",
            "where ", "what ", "who ", "how ", "why ", "please ",
            "stop ", "don't ", "do you ", "are you ", "can you "
        ]
        return markers.contains { lower.contains($0) } || lower.hasPrefix("i ")
    }

    private func looksLikeAlexFragment(_ text: String) -> Bool {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let isMostlyLowercase = clean == clean.lowercased()
        let wordCount = clean.split(separator: " ").count
        return isMostlyLowercase && wordCount <= 8 && !clean.contains("?")
    }

    private func normalizedLine(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    func triggerSpecialEvent(type: MessageType, text: String) {
        addAlexMessage(text, type: type)
        HapticManager.shared.playGlitchHaptic()
    }

    func triggerSystemMessage(_ text: String) {
        messages.append(Message(text: text, isFromMe: false, time: currentTime(), isRead: true, type: .systemAlert))
        HapticManager.shared.playGlitchHaptic()
    }
}
