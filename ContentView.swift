import SwiftUI
import GameplayKit
import UIKit
import Combine
import AVFoundation
import UserNotifications

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 18.0, macOS 15.0, *)
@Generable
struct AlexResponse {
    @Guide(description: """
    A list of 1-2 messages from Alex. 
    CHARACTER VOICE: 
    - Use 'Alex persona': intimate, lowercase, fragmented, and eerily calm. 
    - Messages should feel like a digital ghost reaching out through static.
    - Mention sensory details if appropriate (the cold, the rain, the sound of water).
    CONTENT RULES:
    - First message MUST specifically acknowledge the player's last input.
    - Second message should push the current SCENE GOAL.
    - NEVER repeat sentences found in RECENT CHAT history.
    """)
    var replies: [String]
    
    @Guide(description: """
    Exactly 3 unique player dialogue options. They must be psychologically distinct:
    1. TRUST/CONFIDENCE (Blue): Bold, direct, or empathetic. The player tries to help Alex or stays grounded in logic. 
    2. DENIAL/HOSTILITY (Red): Fearful, angry, or rejecting. The player refuses the reality or blames Alex.
    3. AVOIDANCE/CONFUSION (Gray): Hesitant, lost, or paranoid. The player is overwhelmed by the glitches.
    
    DIALOGUE RULES:
    - Use natural, raw conversational English. 
    - DO NOT use labels like 'Confidence:' or 'Choice 1:'. 
    - NO 'Yes/No' answers; use full, emotive sentences.
    - Every choice must be a direct response to the 'replies' you just wrote.
    """)
    var choices: [String]
}

@available(iOS 18.0, macOS 15.0, *)
@Generable
struct PlayerChoiceTags {
    @Guide(
        description: "Most important emotion tags in the player's latest reply choice.",
        .maximumCount(2)
    )
    var emotions: [String]
    
    @Guide(
        description: "Most important topic tags in the player's latest reply choice.",
        .maximumCount(2)
    )
    var topics: [String]
}
#endif

// MARK: - Message Data Models

enum MessageType: Equatable {
    case text
    case systemAlert
    case image(String)
    case voiceNote(String)
    case lockedFile(String)
}

struct Message: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let isFromMe: Bool
    let time: String
    let isRead: Bool
    let type: MessageType
}

/// rawValue is used as the `currentPath` string identifier.
enum ChoiceType: String {
    case trust      = "trust"
    case denial     = "denial"
    case avoidance  = "avoidance"
}

struct PlayerChoice: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let type: ChoiceType
}

struct FallbackResponse {
    var replies: [String]
    var choices: [String]
}

// MARK: - Runtime Environment Detection

enum RuntimeEnvironment {
    static var isRunningInPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
    
    static var canUseFoundationModels: Bool {
        if isRunningInPreview { return false }
#if targetEnvironment(simulator)
        return false
#else
        return true
#endif
    }
    
    static var foundationModelsDebugLabel: String {
        if isRunningInPreview { return "Preview Fallback" }
#if targetEnvironment(simulator)
        return "Simulator Fallback"
#else
        return canUseFoundationModels ? "Device Model" : "Device Fallback"
#endif
    }
}

// MARK: - Audio Manager
// Multi-channel SFX pool so heartbeat and other sounds can overlap.
// `applyCurrentSFXVolume()` is called whenever sfxVolume changes in Settings.

class AudioManager {
    static let shared = AudioManager()
    
    var bgmPlayer: AVAudioPlayer?
    
    /// SFX pool — allows concurrent sounds without one cutting another off.
    private var sfxPool: [AVAudioPlayer] = []
    private let poolSize = 6
    
    private init() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("AudioManager: Failed to configure audio session — \(error)")
        }
    }
    
    /// Compatibility accessor for external code that still references sfxPlayer.
    var sfxPlayer: AVAudioPlayer? { sfxPool.first }
    
    // MARK: BGM
    
    func playBackgroundMusic(filename: String) {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "mp3") else {
            print("AudioManager: BGM file '\(filename).mp3' not found.")
            return
        }
        do {
            bgmPlayer = try AVAudioPlayer(contentsOf: url)
            bgmPlayer?.numberOfLoops = -1
            bgmPlayer?.volume = AppSettings.shared.musicVolume
            bgmPlayer?.prepareToPlay()
            bgmPlayer?.play()
        } catch {
            print("AudioManager: Failed to play BGM — \(error)")
        }
    }
    
    func stopBackgroundMusic() {
        bgmPlayer?.stop()
    }
    
    // MARK: SFX
    // Each call picks a free slot from the pool (or evicts the oldest)
    // so multiple sounds can play simultaneously.
    
    func playSound(_ filename: String) {
        let name = filename.replacingOccurrences(of: ".mp3", with: "")
        guard let url = Bundle.main.url(forResource: name, withExtension: "mp3") else {
            print("AudioManager: SFX file '\(name).mp3' not found.")
            return
        }

        if let free = sfxPool.first(where: { !$0.isPlaying }),
           let newPlayer = try? AVAudioPlayer(contentsOf: url),
           let idx = sfxPool.firstIndex(of: free) {
            sfxPool[idx] = newPlayer
            newPlayer.volume = AppSettings.shared.sfxVolume
            newPlayer.prepareToPlay()
            newPlayer.play()
        } else if sfxPool.count < poolSize,
                  let newPlayer = try? AVAudioPlayer(contentsOf: url) {
            sfxPool.append(newPlayer)
            newPlayer.volume = AppSettings.shared.sfxVolume
            newPlayer.prepareToPlay()
            newPlayer.play()
        } else if let newPlayer = try? AVAudioPlayer(contentsOf: url) {
            // Pool full — evict oldest slot
            sfxPool[0].stop()
            sfxPool[0] = newPlayer
            newPlayer.volume = AppSettings.shared.sfxVolume
            newPlayer.prepareToPlay()
            newPlayer.play()
        }
    }
    
    /// Applies the current sfxVolume to all active pool players.
    /// Called whenever AppSettings.sfxVolume changes.
    func applyCurrentSFXVolume() {
        let vol = AppSettings.shared.sfxVolume
        sfxPool.forEach { $0.volume = vol }
    }
}

// MARK: - Context Enums

enum PlayerEmotionState: String {
    case hostile = "HOSTILE"
    case neutral = "NEUTRAL"
    case trust   = "TRUST"
}

enum AlexToneState: String {
    case aggressive = "Aggressive"
    case uncertain  = "Uncertain"
    case calm       = "Melancholic"
}

/// Per-scene branching level derived from denialScore.
enum PsycheLevel {
    case low, medium, high, extreme
}

// MARK: - GameplayKit Narrative States
// ─────────────────────────────────────────────────────────────────────────────

class NarrativeState: GKState {
    unowned let manager: GameManager
    let sceneID: String
    let usesLLM: Bool
    let goal: String
    
    init(_ manager: GameManager, sceneID: String, goal: String, usesLLM: Bool = true) {
        self.manager = manager
        self.sceneID = sceneID
        self.goal    = goal
        self.usesLLM = usesLLM
        super.init()
    }
    
    override func didEnter(from previousState: GKState?) {
        manager.currentScene = sceneID
    }
    
    override func isValidNextState(_ stateClass: AnyClass) -> Bool { true }
    
    func getPromptData() -> (goal: String, situation: String) {
        return (goal: "Continue the conversation as Alex.", situation: "You are Alex.")
    }
}

// MARK: Scene 1 — Initial contact (no AI)

final class Scene1State: NarrativeState {
    override func didEnter(from previousState: GKState?) {
        super.didEnter(from: previousState)
        guard !manager.isRestoringFromSave else { return }
        EvidenceBoardManager.shared.unlockFragment(forScene: "S1")
        manager.currentAct = 1
        
        if manager.messages.isEmpty {
            if AppSettings.shared.totalClears > 0 {
                // New loop — Alex shows faint signs of deja vu
                manager.addAlexMessage("wait...", type: .text)
                manager.addAlexMessage("why does it feel like i've asked you this before?", type: .text)
                manager.addAlexMessage("are you still awake?", type: .text)
            } else {
                manager.addAlexMessage("Are you awake?", type: .text)
            }
            manager.setChoices(["Alex?! Is that you?", "Who is this? This isn't funny.", "Ignore"])
        }
    }
}

// MARK: Scene 2 — First Contact (AI)

final class Scene2State: NarrativeState {
    override func getPromptData() -> (goal: String, situation: String) {
        EvidenceBoardManager.shared.unlockFragment(forScene: "S2")
        let goal = "Generate 1-2 Alex messages continuing from the current path. Reference what just happened without naming it directly. Make the player feel the weight of their choice without being explicitly told what it was."
        
        var pathText = ""
        switch manager.currentPath {
        case "trust":     pathText = "Alex sent '...so you still remember me' then 'that's good.' He sounds almost relieved — quieter than expected."
        case "denial":    pathText = "Alex sent 'wow' then 'you really don't recognize me?'. He sounds confused, not angry."
        case "avoidance": pathText = "Alex sent '...' then nothing for four seconds. Then: 'you're reading this' and 'why won't you answer?'. He sounds desperate."
        default: break
        }
        
        var levelText = ""
        switch manager.currentPsycheLevel {
        case .low:            levelText = "Alex's follow-up feels almost like a normal conversation. The wrongness is subtle."
        case .medium:         levelText = "Alex is less settled. Something in his phrasing is off enough to notice but not enough to name."
        case .high, .extreme: levelText = "Alex is more fragmented. Messages arrive faster. He starts to repeat himself slightly."
        }
        
        let situation = """
        WHAT JUST HAPPENED:
        The player made their first choice. Alex responded differently based on how the player engaged.
        \(pathText)
        
        CRITICAL CONTEXT:
        Alex does not know five years have passed. His confusion is genuine — he is not performing patience.
        
        DENIAL LEVEL MODULATION:
        \(levelText)
        """
        return (goal, situation)
    }
}

// MARK: Scene 3 — Image Reveal (AI)

final class Scene3State: NarrativeState {
    override func didEnter(from previousState: GKState?) {
        super.didEnter(from: previousState)
        guard !manager.isRestoringFromSave else { return }
        EvidenceBoardManager.shared.unlockFragment(forScene: "S3")
        manager.refreshAISession()
        
        manager.triggerSpecialEvent(type: .image("alex n friend"), text: "Look closely at the timestamp...")
    }
    
    override func getPromptData() -> (goal: String, situation: String) {
        let goal = "Generate 1-2 Alex messages continuing the pressure of this moment. Reference the photo obliquely — not 'look at the photo' but something that assumes the player already sees what Alex sees."
        
        var pathText = ""
        switch manager.currentPath {
        case "trust":     pathText = "Alex says: 'you took that' / 'remember?'. He is sharing a memory gently."
        case "denial":    pathText = "Alex says: 'that's not enough for you?'. He sounds hurt that the player resists the proof."
        case "avoidance": pathText = "Alex says: 'you were there' / 'next to me'. Two statements. No question. No accusation. Just facts."
        default: break
        }
        
        var levelText = ""
        switch manager.currentPsycheLevel {
        case .low:            levelText = "Alex follows up warmly. The hint in the background feels like a background detail."
        case .medium:         levelText = "Alex is more pointed. The player might start to feel watched rather than missed."
        case .high, .extreme: levelText = "Alex is insistent. The glitch and haptic have disoriented the player. Messages arrive fast."
        }
        
        let situation = """
        WHAT JUST HAPPENED:
        A photo appeared on screen (IMG_01). Two people, heavily blurred. Timestamp reads 2:14 AM.
        \(pathText)
        
        WHAT THE PHOTO MEANS:
        It is proof of presence — proof that Alex was somewhere real, that there was a moment they shared.
        
        DENIAL LEVEL MODULATION:
        \(levelText)
        """
        return (goal, situation)
    }
}

// MARK: Scene 4 — Guilt Build & Voice Reveal (AI)

final class Scene4State: NarrativeState {
    override func didEnter(from previousState: GKState?) {
        super.didEnter(from: previousState)
        guard !manager.isRestoringFromSave else { return }
        EvidenceBoardManager.shared.unlockFragment(forScene: "S4")
        
        manager.glitchTrigger += 1
        manager.triggerSystemMessage("ERROR: CONNECTION UNSTABLE. CHAT LOGS AUTO-SCROLLING.")
        
        manager.addAlexMessage("just say something", type: .text)
        manager.addAlexMessage("please", type: .text)
        manager.addAlexMessage("don't leave me", type: .text)
        
        // Send voice note immediately without waiting for player input
        let asset: String
        switch manager.currentPsycheLevel {
        case .low:            asset = "VN_L1.mp3"
        case .medium:         asset = "VN_M1.mp3"
        case .high, .extreme: asset = "VN_H1.mp3"
        }
        manager.triggerSpecialEvent(type: .voiceNote(asset), text: "Listen to me...")
    }
    
    override func getPromptData() -> (goal: String, situation: String) {
        let goal = "React to the scrolling chat logs and the voice note you just sent. This is the final communication before you disappear again. Make it sound like time is running out. Generate exactly 1 short Alex message."
        
        var audioDetail = ""
        switch manager.currentPsycheLevel {
        case .low:            audioDetail = "Calm voice note. Soft rain, slow breathing."
        case .medium:         audioDetail = "Unstable voice. Fast breathing, 'are you there?'."
        case .high, .extreme: audioDetail = "Chaotic voice. Footsteps, horn, fall, distortion."
        }
        
        let situation = """
        WHAT JUST HAPPENED:
        The screen glitched. Old chat logs from 5 years ago auto-scrolled.
        You sent: "just say something", "please", "don't leave me".
        IMMEDIATELY after, you sent a Voice Note. 
        AUDIO DETAIL: \(audioDetail)
        
        THE WEIGHT: 
        This is the emotional peak. You don't know the player thought you were dead. You just know they went quiet. Do not resolve anything.
        """
        return (goal, situation)
    }
}

// MARK: Scene 5 — Cliffhanger / Bridge (no AI)

final class Scene5State: NarrativeState {
    override func didEnter(from previousState: GKState?) {
        super.didEnter(from: previousState)
        guard !manager.isRestoringFromSave else { return }
        EvidenceBoardManager.shared.unlockFragment(forScene: "S5")
        
        manager.refreshAISession()
        manager.currentAct = 2
        
        if !manager.hasSentEndingFile {
            manager.triggerSpecialEvent(type: .lockedFile("FILE_01.enc"), text: "I can't stay. Open this when you're ready.")
            manager.hasSentEndingFile = true
        }
        
        manager.currentChoices = []
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            self.manager.turnCount = 6
            self.manager.stateMachine?.enter(Scene6State.self)
        }
    }
}

// MARK: Scene 6 — Decrypt File / Act 2 Begin (AI)

final class Scene6State: NarrativeState {
    override func didEnter(from previousState: GKState?) {
        super.didEnter(from: previousState)
        guard !manager.isRestoringFromSave else { return }
        EvidenceBoardManager.shared.unlockFragment(forScene: "S6")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let glitchText = """
            ERROR: FILE_01.enc DECRYPTING...
            PROGRESS: 34%... 61%... 89%... INCOMPLETE
            PARTIAL CONTENTS AVAILABLE:
            
            "if you're reading this, you're too late."
            Loc: -6.2088, 106.8456
            Time: 18 Oct 2019, 02:14 AM
            """
            self.manager.triggerSystemMessage(glitchText)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            let triggerChoice = PlayerChoice(text: "[SYSTEM: File opened by player]", type: .trust)
            self.manager.lastPlayerChoice = triggerChoice
            Task { await self.manager.generateAlexReply() }
        }
    }
    
    override func getPromptData() -> (goal: String, situation: String) {
        let goal = "React to the fact that the player just opened the encrypted file you sent. Do not explain the file. Just react to them opening it. Generate 1 short message."
        
        var pathText = ""
        switch manager.currentPath {
        case "trust":     pathText = "You sound relieved, sad, almost in disbelief. E.g., 'you opened it' or 'so you still care'."
        case "denial":    pathText = "You sound defensive, cornering the player. E.g., 'i knew you would open it' or 'now you know'."
        case "avoidance": pathText = "You are quiet, ominous. E.g., 'there's one more file' or 'you're not ready'."
        default: break
        }
        
        let situation = """
        WHAT JUST HAPPENED:
        The encrypted file you sent earlier just forcefully opened itself on the player's screen.
        It revealed a note: "kalau kamu baca ini, berarti kamu terlambat." (if you read this, you're too late) and the timestamp 02:14 AM.
        
        HOW YOU REACT:
        \(pathText)
        """
        return (goal, situation)
    }
}

// MARK: Scene 7 — Memory Bleed (AI)

final class Scene7State: NarrativeState {
    override func didEnter(from previousState: GKState?) {
        super.didEnter(from: previousState)
        guard !manager.isRestoringFromSave else { return }
        EvidenceBoardManager.shared.unlockFragment(forScene: "S7")
        manager.startHeartbeat()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.manager.triggerSystemMessage("WARNING: TEMPORAL DISCREPANCY DETECTED. MESSAGE ORIGIN: 18 OCT 2019.")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.manager.triggerSpecialEvent(
                type: .image("IMG02"),
                text: "On that bridge... a part of me still remains."
            )
        }
    }
    
    override func getPromptData() -> (goal: String, situation: String) {
        let goal = "Alex is experiencing a 'memory bleed'. You are sending messages as if it's 5 years ago, but also reacting to the current photo of the bridge."
        
        var pathText = ""
        let score = manager.denialScore
        
        if score <= -7 {
            pathText = "TRUST: You confirm it was you on the bridge. You sound lonely but not angry."
        } else if score >= 8 {
            pathText = "DENIAL: You are hostile. You blame the player for not being there."
        } else {
            pathText = "AVOIDANCE: You are hauntingly calm."
        }
        
        let situation = """
        ACT 2 - SCENE 7: THE MEMORY BLEED
        Context: You just sent IMG_02 showing a silhouette on a bridge at 2:13 AM. 
        Glitch: You remember things the player 'said' 5 years ago
        
        YOUR REACTION:
        \(pathText)
        Instruction: Keep it very short. Max 2 small messages. No caps.
        """
        return (goal, situation)
    }
}

// MARK: Scene 8 — System Break / Climax (AI)

final class Scene8State: NarrativeState {
    override func didEnter(from previousState: GKState?) {
        super.didEnter(from: previousState)
        guard !manager.isRestoringFromSave else { return }
        EvidenceBoardManager.shared.unlockFragment(forScene: "S8")
        
        manager.refreshAISession()
        manager.currentAct = 3
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.manager.triggerSystemMessage("ERROR: MESSAGE QUEUED SINCE 18 OCT 2019.")
            self.manager.glitchTrigger += 2
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            self.manager.triggerSystemMessage("RECIPIENT STATUS: UNKNOWN. DELIVERY DELAYED: 1,826 DAYS.")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
            self.manager.triggerSpecialEvent(
                type: .voiceNote("VN_X1.mp3"),
                text: "i've been trying to reach you since that night..."
            )
        }
    }
    
    override func getPromptData() -> (goal: String, situation: String) {
        let goal = "Alex confesses that this is the first time his messages actually reached the player after 5 years of trying."
        
        var pathText = ""
        let score = manager.denialScore
        
        if score <= -7 {
            pathText = "TRUST: You feel like this is a goodbye. 'you're the only one who still reads my messages'."
        } else if score >= 8 {
            pathText = "DENIAL: You are angry and hurt. 'why did you never come? i know you're reading this'."
        } else {
            pathText = "AVOIDANCE: You are eerily calm. 'i'm not mad... i just want to know why'."
        }
        
        let situation = """
        ACT 2 - SCENE 8: SYSTEM BREAK (THE CLIMAX)
        Context: The system is crashing. You admit you've been stuck in a loop since 2019, trying to send these texts.
        The player just heard VN_S8 (footsteps, wind, silence).
        
        ALEX'S REACTION:
        \(pathText)
        Instruction: This is the emotional peak. Be vulnerable or terrifyingly honest. Use English only.
        """
        return (goal, situation)
    }
}

// MARK: Scene Ending — Final Resolution (no AI)

final class SceneEndingState: NarrativeState {
    override func didEnter(from previousState: GKState?) {
        super.didEnter(from: previousState)
        guard !manager.isRestoringFromSave else { return }
        EvidenceBoardManager.shared.unlockFragment(forScene: "ENDING")
        
        manager.stopHeartbeat()
        manager.currentAct = 3
        manager.currentChoices = []
        
        let score = manager.denialScore
        
        if score <= -8 {
            executeEndingA()
        } else if score >= 8 {
            executeEndingB()
        } else {
            executeEndingC()
        }
    }
    
    private func showRestartOption() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.manager.currentChoices = [
                PlayerChoice(text: "Play Again", type: .trust),
                PlayerChoice(text: "Quit Game",  type: .avoidance)
            ]
        }
    }
    
    // MARK: Ending A — Trust Path
    private func executeEndingA() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.manager.triggerSystemMessage("FILE_01.enc DECRYPTION COMPLETE.")
            self.manager.addAlexMessage("""
            i waited for you until 2 am. i thought you forgot.
            this is not your fault. 
            if you ever read this, i want you to know i'm not mad.
            """, type: .text)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
            self.manager.addAlexMessage("thank you for reading.", type: .text)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) {
            self.manager.triggerSystemMessage("Alex: Read at 2:14 AM ✓✓")
            withAnimation { self.manager.isEndingFinished = true }
            self.showRestartOption()
        }
    }
    
    // MARK: Ending B — Denial Path
    private func executeEndingB() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.manager.triggerSystemMessage("FILE_01.enc OPENED: CALL_LOG_2019")
            self.manager.triggerSystemMessage("""
            UNANSWERED CALL: [PLAYER]
            18 Oct 2019, 02:13 AM
            """)
            // Re-trigger crack; increment to ensure onChange fires even if already non-zero
            if self.manager.crackTrigger == 0 {
                self.manager.crackTrigger = 1
            } else {
                self.manager.crackTrigger += 1
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            self.manager.addAlexMessage("2:14 AM. you're reading this now.", type: .text)
            self.manager.addAlexMessage("just like the last time.", type: .text)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) {
            self.manager.triggerSystemMessage("ERROR: YOU ARE NOW IN THE QUEUE.")
            self.manager.glitchTrigger += 5
            withAnimation { self.manager.isEndingFinished = true }
            self.showRestartOption()
        }
    }
    
    // MARK: Ending C — Neutral / Loop Path
    private func executeEndingC() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.manager.addAlexMessage("maybe i'm still here. maybe not.", type: .text)
            self.manager.addAlexMessage("all i know is: you're reading this.", type: .text)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
            self.manager.addAlexMessage("that's enough for me.", type: .text)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
            self.manager.triggerSystemMessage("CONNECTION RESTARTING...")
            withAnimation { self.manager.isEndingFinished = true }
            self.showRestartOption()
        }
    }
}

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
                content.sound = .defaultCritical
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
        
        messages.append(Message(text: choice.text, isFromMe: true, time: currentTime(), isRead: true, type: .text))
        
        lastPlayerChoice = choice
        currentPath      = choice.type.rawValue
        currentChoices.removeAll()
        
        UnknownContactManager.shared.checkAndSchedule(denialScore: denialScore)
        
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
        
        Task {
            await refineChoiceContext(from: choice)
            let _ = Task { await generateAlexReply() }
            try? await Task.sleep(nanoseconds: 15_000_000_000)
            if self.currentChoices.isEmpty && !self.isTyping {
                print("WATCHDOG: Alex got stuck — forcing recovery.")
                await generateAlexReply()
            }
        }
    }
    
    // MARK: - Restart
    
    func restartGame() {
        messages.removeAll()
        
        denialScore     = 0
        turnCount       = 0
        glitchTrigger   = 0
        shadowTrigger   = 0
        crackTrigger    = 0  // reset crack so GlitchSceneView hides the overlay
        currentAct      = 1
        currentPath     = "none"
        hasSentEndingFile   = false
        shouldQuit          = false
        isEndingFinished    = false
        
        fakeBatteryLevel = 85.0
        fakeTime         = "2:14"
        startFakeClockLogic()
        
        EvidenceBoardManager.shared.resetFragments()
        UnknownContactManager.shared.reset()
        
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

// MARK: - Hardware Controllers
// ─────────────────────────────────────────────────────────────────────────────

class HapticManager {
    static let shared = HapticManager()
    
    func playGlitchHaptic() {
        guard AppSettings.shared.hapticsEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }
    
    func playTypeHaptic() {
        guard AppSettings.shared.hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

// MARK: - SwiftUI Views
// ─────────────────────────────────────────────────────────────────────────────

// MARK: Lock Screen

struct LockScreenView: View {
    @Binding var isUnlocked: Bool
    let onAppearAction: () -> Void
    
    @State private var timeString = "2:13"
    @State private var showGhostNotifications = true
    @State private var brightnessDim: Double = 0.0
    @State private var glitchOpacity: Double = 0.0
    @State private var showAlexNotification = false
    @State private var canUnlock = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Color(white: 0.1).ignoresSafeArea()
            Color.black.opacity(brightnessDim).ignoresSafeArea()
            Color.red.opacity(glitchOpacity).ignoresSafeArea()
            
            VStack {
                VStack(spacing: 0) {
                    Text(timeString)
                        .font(.system(size: 80, weight: .thin, design: .rounded))
                        .foregroundColor(.white)
                    Text("Friday, October 18")
                        .font(.headline).foregroundColor(.white.opacity(0.8))
                }
                .padding(.top, 40)
                
                Spacer()
                
                if showGhostNotifications {
                    VStack(spacing: 8) {
                        NotificationChip(title: "Instagram", message: "Someone liked your photo")
                        NotificationChip(title: "WhatsApp",  message: "Mom: Are you coming home?")
                        NotificationChip(title: "System",    message: "Storage almost full")
                    }
                    .transition(.opacity)
                    .padding(.horizontal)
                }
                
                if showAlexNotification {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "message.fill").foregroundColor(.green)
                            Text("MESSAGES").font(.caption).fontWeight(.bold).foregroundColor(.gray)
                            Spacer()
                            Text("Now").font(.caption).foregroundColor(.gray)
                        }
                        Text("Alex").font(.headline).foregroundColor(.white)
                        Text("Are you awake?").font(.subheadline).foregroundColor(.white.opacity(0.9))
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(18)
                    .padding(.horizontal)
                    .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
                    .onTapGesture {
                        if canUnlock {
                            HapticManager.shared.playTypeHaptic()
                            withAnimation(.spring()) { isUnlocked = true }
                        }
                    }
                }
                
                Spacer()
                
                if canUnlock {
                    Text("Swipe up or tap notification to open")
                        .font(.caption).foregroundColor(.white.opacity(0.4))
                        .padding(.bottom, 30)
                }
            }
        }
        .onAppear { runCinematicSequence() }
    }
    
    func runCinematicSequence() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 2.5)) { brightnessDim = 0.6 }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation(.none) { timeString = "2:14" }
                HapticManager.shared.playGlitchHaptic()
                withAnimation(.easeInOut(duration: 0.1)) { glitchOpacity = 0.4 }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    glitchOpacity = 0.0
                    withAnimation(.easeOut(duration: 0.6)) { showGhostNotifications = false }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                            showAlexNotification = true
                        }
                        HapticManager.shared.playGlitchHaptic()
                        canUnlock = true
                        onAppearAction()
                    }
                }
            }
        }
    }
}

// MARK: Notification Chip (Lock Screen)

struct NotificationChip: View {
    let title: String
    let message: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption2).fontWeight(.bold).foregroundColor(.gray)
                Text(message).font(.subheadline).foregroundColor(.white)
            }
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Color.white.opacity(0.15))
        .cornerRadius(14)
    }
}

// MARK: - Content View (Root)

struct ContentView: View {
    
    @StateObject private var gameManager = GameManager()
    @State private var currentScreen: AppScreen = .splash
    @State private var isUnlocked = false
    @Environment(\.scenePhase) var scenePhase
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            Group {
                switch currentScreen {
                    
                case .splash:
                    SplashScreenView {
                        withAnimation(.easeIn(duration: 0.5)) {
                            currentScreen = .mainMenu
                            AudioManager.shared.playBackgroundMusic(filename: "Horror")
                        }
                    }
                    .transition(.opacity)
                    
                case .mainMenu:
                    MainMenuView(
                        onNewGame: {
                            GameSaveManager.shared.clearSave()
                            EvidenceBoardManager.shared.resetFragments()
                            UnknownContactManager.shared.reset()
                            withAnimation(.easeIn(duration: 0.4)) { currentScreen = .contentWarning }
                        },
                        onContinue: {
                            GameSaveManager.shared.restore(into: gameManager)
                            isUnlocked = false
                            withAnimation(.easeIn(duration: 0.35)) { currentScreen = .game }
                        }
                    )
                    .transition(.opacity)
                    
                case .contentWarning:
                    ContentWarningView {
                        withAnimation(.easeIn(duration: 0.4)) { currentScreen = .lockscreen }
                    }
                    .transition(.opacity)
                    
                case .lockscreen:
                    LockScreenView(isUnlocked: $isUnlocked) {
                        gameManager.triggerInitialLockscreenEvent()
                    }
                    .onChange(of: isUnlocked) { _, unlocked in
                        if unlocked {
                            withAnimation(.easeIn(duration: 0.35)) { currentScreen = .game }
                        }
                    }
                    .transition(.opacity)
                    
                case .game:
                    ChatRoomView(gameManager: gameManager) {
                        gameManager.restartGame()
                        isUnlocked = false
                        AudioManager.shared.stopBackgroundMusic()
                        AudioManager.shared.playBackgroundMusic(filename: "Horror")
                        withAnimation(.easeIn(duration: 0.5)) { currentScreen = .mainMenu }
                    }
                    .transition(.opacity)
                }
            }
            UnknownContactBannerView()
                .padding(.top, -400)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                GameSaveManager.shared.save(from: gameManager)
                gameManager.scheduleHorrorNotification()
            } else if newPhase == .active {
                gameManager.cancelNotifications()
            }
        }
    }
}

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

// MARK: - Debug Status View

struct DebugStatusView: View {
    let denialScore: Int
    let currentAct: Int
    let currentScene: String
    let modelStatus: String
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                DebugStatChip(label: "Denial", value: "\(denialScore)", tint: .red)
                DebugStatChip(label: "Act",    value: "\(currentAct)", tint: .blue)
                DebugStatChip(label: "Scene",  value: currentScene,    tint: .orange)
                DebugStatChip(label: "Mode",   value: modelStatus,     tint: .purple)
            }
            .padding(12)
        }
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.14), lineWidth: 1))
    }
}

private struct DebugStatChip: View {
    let label: String
    let value: String
    let tint: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption2).foregroundColor(.white.opacity(0.65))
            Text(value).font(.caption.weight(.semibold)).foregroundColor(.white)
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(tint.opacity(0.18), in: Capsule())
        .overlay(Capsule().stroke(tint.opacity(0.45), lineWidth: 1))
    }
}

// MARK: - Chat Bubble Shape

struct ChatBubbleShape: Shape {
    var isFromMe: Bool
    func path(in rect: CGRect) -> Path {
        Path(UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: isFromMe ? [.topLeft, .topRight, .bottomLeft] : [.topLeft, .topRight, .bottomRight],
            cornerRadii: CGSize(width: 18, height: 18)
        ).cgPath)
    }
}

// MARK: - Choice Keyboard

struct ChoiceKeyboardView: View {
    let choices: [PlayerChoice]
    let denialScore: Int
    let onSelect: (PlayerChoice) -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Capsule().fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 5).padding(.top, 8)
            
            VStack(spacing: 8) {
                ForEach(choices) { choice in
                    Button(action: { onSelect(choice) }) {
                        Text(applyZalgo(to: choice.text, intensity: denialScore))
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.3))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
                            )
                            .padding(.horizontal)
                    }
                }
            }
            .padding(.bottom, 30)
        }
        .frame(maxWidth: .infinity)
        .background(Color.red.opacity(0.45))
        .cornerRadius(20, corners: [.topLeft, .topRight])
        .shadow(radius: 10)
    }
    
    /// Applies Zalgo-style diacritic corruption when denial score exceeds 10.
    private func applyZalgo(to text: String, intensity: Int) -> String {
        guard intensity > 10 else { return text }
        
        let zalgoMarks = [
            "\u{030d}", "\u{030e}", "\u{0304}", "\u{0305}", "\u{033f}", "\u{0311}",
            "\u{0306}", "\u{0310}", "\u{0352}", "\u{0357}", "\u{0351}", "\u{0301}",
            "\u{0300}", "\u{0316}", "\u{0317}", "\u{0318}", "\u{0319}", "\u{031c}",
            "\u{031d}", "\u{0324}", "\u{0325}", "\u{0326}", "\u{032e}", "\u{032f}",
            "\u{0330}", "\u{0331}", "\u{0332}", "\u{0333}", "\u{0339}", "\u{033a}",
            "\u{033b}", "\u{033c}", "\u{0345}", "\u{0347}", "\u{0348}", "\u{0349}",
            "\u{034a}", "\u{034b}", "\u{034c}", "\u{034d}", "\u{034e}", "\u{0353}",
            "\u{0354}", "\u{0355}", "\u{0356}", "\u{0359}", "\u{035a}", "\u{0323}"
        ]
        
        var result = ""
        for char in text {
            result.append(char)
            if char.isWhitespace { continue }
            
            let marksCount = intensity > 15 ? Int.random(in: 1...3) : Int.random(in: 0...1)
            for _ in 0..<marksCount {
                if let mark = zalgoMarks.randomElement() {
                    result.append(Character(UnicodeScalar(mark)!))
                }
            }
        }
        return result
    }
}

// MARK: - View Extension: Corner Radius

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path {
        Path(UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius)).cgPath)
    }
}

// MARK: - Preview

#Preview {
    ContentView().preferredColorScheme(.dark)
}
