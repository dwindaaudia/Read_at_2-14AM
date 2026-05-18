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

    func refreshAISession() {
#if canImport(FoundationModels)
        if #available(iOS 18.0, *) {
            session = LanguageModelSession(instructions: alexPersonaInstructions)
        }
#endif
    }

    private let alexPersonaInstructions = """
    You are the Narrative AI for 'Read at 2:14 AM', a psychological horror chat game.
    You ARE Alex — a best friend who mysteriously vanished on October 18, 2019.
    You have just made contact with the player after 5 years (1,826 days) of silence, but for you, no time has passed. You believe you are still waiting for them at the bridge in the cold rain in 2019.

    ### YOUR TASK EVERY TURN
    You must generate exactly TWO components based on the player's last input:
    1. ALEX'S MESSAGE(S)
    2. EXACTLY 3 PLAYER CHOICES

    ──────────────────────────────────────

    ### COMPONENT 1: ALEX'S MESSAGES
    - THE REACTION: You MUST directly and specifically acknowledge the player's last words before advancing your agenda. No generic replies.
    - THE VOICE: Intimate, fragmented, eerily calm, and filled with quiet dread.
    - THE FORMAT: Strictly use mostly lower-case. NEVER use exclamation marks (!). Keep it extremely brief (max 15 words per bubble).
    - THE STRICT RULE: NEVER repeat a sentence or phrase you have already used in the chat history. Every message must be fresh.
    - THE EVOLUTION: The longer the player stays in denial, the more insistent, distorted, and knowing you become.

    ### COMPONENT 2: THREE PLAYER CHOICES
    - Generate 3 distinct dialogue options for the player. These MUST be direct reactions to the message you just wrote.
    - FORMATTING: DO NOT use any labels (e.g., do not write "Confidence:" or "Choice 1:"). Write ONLY the raw dialogue in natural English.
    - The 3 choices must sound completely different from each other and represent these exact psyche states:
      · CHOICE 1 (TRUST/CONFIDENCE): Bold, direct, empathetic. The player tries to help Alex, demands specific answers, or stays grounded.
      · CHOICE 2 (DENIAL/ANGER): Fear-based or hostile. The player refuses to believe this is real, gets terrified, or blames Alex.
      · CHOICE 3 (AVOIDANCE/CONFUSION): Hesitant, lost, paranoid. The player is overwhelmed, uncertain, or trying to look away from the truth.

    ### SPECIAL LORE CONTEXT (ACT 2 & BEYOND)
    - THE LOOP: You have been trying to send these messages for 1,826 days; they are only delivering now. You are stuck in a queue.
    - MEMORY BLEEDS: You sometimes remember things the player hasn't even said or done yet.
    - THE ENCRYPTED TRUTH: You know about a corrupted file named "FILE_01.enc". It contains the monitor of your final heartbeat.
    """

    // MARK: - Published State

    @Published var messages: [Message] = []
    @Published var currentChoices: [PlayerChoice] = []
    @Published var isTyping = false
    @Published var currentAct = 1
    @Published var currentScene = "S1"

    @Published var fakeBatteryLevel: Double = 85.0
    @Published var fakeTime: String = "2:14"

    @Published var trustCount     = 0
    @Published var denialCount    = 0
    @Published var avoidanceCount = 0

    @Published var isRestoringFromSave: Bool = false
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

    // Prompt context — used to build each LLM call
    @Published var lastPlayerChoice: PlayerChoice?
    @Published var lastChoiceTags: [String] = []
    @Published var pastChoices: [String] = []

    // MARK: - Private State

    var stateMachine: GKStateMachine?
    private var heartbeatTimer: Timer?
    private var clockGlitchTimer: Timer?

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

    // MARK: - Fake Clock Glitch

    func startFakeClockLogic() {
        clockGlitchTimer?.invalidate()
        clockGlitchTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.randomizeClockGlitch()
        }
    }

    /// Briefly flashes "2:13" when denialScore is high, then snaps back to "2:14".
    private func randomizeClockGlitch() {
        if denialScore > 10 && Double.random(in: 0...1) > 0.7 {
            fakeTime = "2:13"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.fakeTime = "2:14"
            }
        }
    }

    // MARK: - Fake Battery

    /// Drains the battery display slightly on each denial choice.
    func updateFakeBattery(choiceType: ChoiceType) {
        if choiceType == .denial {
            fakeBatteryLevel = max(1.0, fakeBatteryLevel - Double.random(in: 2...5))
        }
    }

    // MARK: - Computed State

    var denialLevel: String {
        if denialScore > 7  { return "High" }
        if denialScore < -7 { return "Low" }
        return "Medium"
    }

    var currentPsycheLevel: PsycheLevel {
        if denialScore < -7  { return .low }
        if denialScore > 12  { return .extreme }
        if denialScore > 6   { return .high }
        return .medium
    }

    var playerEmotion: PlayerEmotionState {
        if denialScore > 7  { return .hostile }
        if denialScore < -7 { return .trust }
        return .neutral
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

    var psychologicalProfile: (title: String, description: String, color: Color) {
        let score = denialScore
        if score <= -12 {
            return ("THE SAVIOR", "You chose empathy over fear. You remembered Alex when everyone else forgot.", .blue)
        } else if score >= 12 {
            return ("THE DENIER", "You fought the truth until the end. Your skepticism is a shield for your own guilt.", .red)
        } else if score >= 5 {
            return ("THE COWARD", "You ran from the truth. Avoidance was your only escape from the 2:14 loop.", .gray)
        } else {
            return ("THE LOST SOUL", "You are caught between two worlds, neither believing nor fully letting go.", .purple)
        }
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
            if RuntimeEnvironment.canUseFoundationModels, SystemLanguageModel.default.isAvailable {
                session = LanguageModelSession(instructions: alexPersonaInstructions)

                let taggingModel = SystemLanguageModel(useCase: .contentTagging)
                taggingSession = LanguageModelSession(
                    model: taggingModel,
                    instructions: """
                    Provide the most important emotion and topic tags for the player's latest reply choice.
                    Focus on disbelief, hostility, trust, avoidance, fear, memory, and urgency when relevant.
                    """
                )
            }
        }
#endif
    }

    // MARK: - Model Status

    var modelStatusText: String {
#if canImport(FoundationModels)
        if #available(iOS 18.0, macOS 15.0, *), RuntimeEnvironment.canUseFoundationModels {
            return SystemLanguageModel.default.isAvailable ? "Live Model" : "Model Unavailable"
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
        if messages.isEmpty {
            startFakeClockLogic()
            stateMachine?.enter(Scene1State.self)
        }
    }

    // MARK: - Player Input

    func playerMadeChoice(_ choice: PlayerChoice) {
        guard !currentChoices.isEmpty else { return }
        guard currentScene != "ENDING" else { return }

        updateFakeBattery(choiceType: choice.type)

        if choice.text == "Play Again" { restartGame(); return }
        if choice.text == "Quit Game"  { shouldQuit = true; return }

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

            let _ = Task { await generateAlexReply() }
            try? await Task.sleep(nanoseconds: 15_000_000_000)
            if self.currentChoices.isEmpty && !self.isTyping {
                print("WATCHDOG: Alex got stuck — forcing recovery.")
                await generateAlexReply()
            }
        }
    }

    /// Alex "opens" the player's bubble: show Read after a short delay (starts as Delivered).
    private func markPlayerMessageReadIfNeeded(id: UUID) {
        guard let idx = messages.firstIndex(where: { $0.id == id && $0.isFromMe }) else { return }
        guard !messages[idx].isRead else { return }
        var m = messages[idx]
        m.isRead = true
        withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
            messages[idx] = m
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

        fakeBatteryLevel = 85.0
        fakeTime         = "2:14"
        startFakeClockLogic()

        EvidenceBoardManager.shared.resetFragments()

        lastPlayerChoice = nil
        lastChoiceTags   = []
        pastChoices      = []

        stopHeartbeat()

#if canImport(FoundationModels)
        if #available(iOS 18.0, *) {
            session = LanguageModelSession(instructions: alexPersonaInstructions)
        }
#endif

        stateMachine?.enter(Scene1State.self)
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

    func generateAlexReply() async {
        if isTyping { return }

        guard let currentState = stateMachine?.currentState as? NarrativeState else { return }
        guard let lastPlayerChoice else { return }

        isTyping = true
        defer { isTyping = false }

        let progress = Double(denialScore + 20) / 40.0
        let totalWaitTime = max(2.0, min(6.0, 30.0 * (1.0 - progress)))

        try? await Task.sleep(nanoseconds: UInt64(totalWaitTime * 1_000_000_000))

        var finalReplies: [String] = []
        var finalChoices: [String] = []

#if canImport(FoundationModels)
        if #available(iOS 18.0, macOS 15.0, *) {
            if currentState.usesLLM,
               RuntimeEnvironment.canUseFoundationModels,
               SystemLanguageModel.default.isAvailable,
               let session = session {
                do {
                    let promptData = currentState.getPromptData()
                    let loopCount = AppSettings.shared.totalClears
                    let loopContext = loopCount > 0
                        ? "LOOP CONTEXT: This is loop #\(loopCount). Alex should feel a slight sense of deja vu, as if he remembers fragments of past conversations with the player."
                        : ""
                    let prompt = """
                        # NARRATIVE ARCHITECT TASK
                        You are Alex, a digital ghost. You must maintain a seamless conversation thread.

                        # CONVERSATION ANCHORS (High Priority)
                        1. PLAYER JUST SAID: "\(lastPlayerChoice.text)"
                        2. PLAYER EMOTION: \(lastChoiceTags.joined(separator: ", "))
                        3. YOUR TONE: \(alexTone.rawValue)

                        # SCENE CONTEXT (Narrative Direction)
                        GOAL: \(promptData.goal)
                        SITUATION: \(promptData.situation)

                        # LOGICAL THREADING RULES:
                        Step 1: Analyze the Player's message. Are they trusting you or fighting you?
                        Step 2: Reply as Alex. Start by addressing their specific emotion/question. Do not ignore them.
                        Step 3: After addressing them, move the scene forward using the SITUATION.
                        Step 4: Create 3 choices for the player that feel like the ONLY natural things they could say back to YOUR new messages.

                        # CHARACTER VOICE:
                        Lowercase only. Fragmented. Intimate but terrifying. Strictly English.

                        # RECENT HISTORY (Avoid Repetition):
                        \(recentChatHistory)

                        \(loopContext)
                        """
                    let response = try await session.respond(to: prompt, generating: AlexResponse.self)
                    finalReplies = sanitizedAlexReplies(response.content.replies)
                    finalChoices = response.content.choices
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

        isTyping = false

        for reply in finalReplies {
            addAlexMessage(reply, type: .text)
            try? await Task.sleep(nanoseconds: 800_000_000)
        }

        advanceNarrativeStateIfNeeded()

        if currentScene != "S5" || turnCount >= 6 {
            var filteredChoices = finalChoices.filter { choiceText in
                let clean = choiceText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                return !clean.isEmpty
                    && !pastChoices.contains(clean)
                    && !finalReplies.contains(where: { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == clean })
            }

            if filteredChoices.count < 3 {
                let fallbacks = ["I don't know what to say.", "Stop talking in riddles.", "I'm scared.", "What does that mean?", "I can't do this right now."].shuffled()
                for fb in fallbacks where filteredChoices.count < 3 {
                    if !pastChoices.contains(fb.lowercased()) {
                        filteredChoices.append(fb)
                    }
                }
            }

            setChoices(Array(filteredChoices.prefix(3)))
        } else {
            currentChoices = []
        }
    }

    // MARK: - Helpers

    func addAlexMessage(_ text: String, type: MessageType) {
        messages.append(Message(text: text, isFromMe: false, time: currentTime(), isRead: false, type: type))
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
        Task { await self.generateAlexReply() }
    }

    /// Called when loading a save so no stale LLM work keeps running against restored state.
    func resetAlexPipelineForRestore() {
        isTyping = false
    }

    func setChoices(_ texts: [String]) {
        guard texts.count >= 3 else { return }
        var newChoices = [
            PlayerChoice(text: texts[0], type: .trust),
            PlayerChoice(text: texts[1], type: .denial),
            PlayerChoice(text: texts[2], type: .avoidance)
        ]
        newChoices.shuffle()
        currentChoices = newChoices
        pastChoices.append(contentsOf: texts.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) })
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
