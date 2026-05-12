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

// Tambah rawValue agar bisa dipakai sebagai currentPath string
enum ChoiceType: String {
    case trust = "trust"
    case denial = "denial"
    case avoidance = "avoidance"
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

class AudioManager {
    static let shared = AudioManager()
    var bgmPlayer: AVAudioPlayer?
    var sfxPlayer: AVAudioPlayer?
    
    func playSound(_ filename: String) {
            guard let url = Bundle.main.url(forResource: filename, withExtension: "mp3") else {
                print("SFX file \(filename).mp3 not found!")
                return
            }
            
            do {
                sfxPlayer = try AVAudioPlayer(contentsOf: url)
                sfxPlayer?.volume = 0.8
                sfxPlayer?.play()
            } catch {
                print("Failed to play sound: \(error)")
            }
        }

    func playBackgroundMusic(filename: String) {
        // Mencari file mp3 di dalam project
        guard let url = Bundle.main.url(forResource: filename, withExtension: "mp3") else {
            print("Audio file \(filename).mp3 not found!")
            return
        }
        
        do {
            bgmPlayer = try AVAudioPlayer(contentsOf: url)
            bgmPlayer?.numberOfLoops = -1 // Angka -1 membuat audio looping tanpa henti
            bgmPlayer?.volume = 0.5 // Atur volume (0.0 sampai 1.0)
            bgmPlayer?.prepareToPlay()
            bgmPlayer?.play()
        } catch {
            print("Failed to play background music: \(error)")
        }
    }
    
    func stopBackgroundMusic() {
        bgmPlayer?.stop()
    }
}

// MARK: - Context Enums
enum PlayerEmotionState: String {
    case hostile = "HOSTILE"
    case neutral = "NEUTRAL"
    case trust = "TRUST"
}

enum AlexToneState: String {
    case aggressive = "Aggressive"
    case uncertain = "Uncertain"
    case calm = "Melancholic"
}

// Dari file lama — dipakai per-scene untuk branching narasi
enum PsycheLevel {
    case low, medium, high
}

// MARK: - GameplayKit Narrative States

class NarrativeState: GKState {
    unowned let manager: GameManager
    let sceneID: String
    let usesLLM: Bool
    let goal: String
    
    init(_ manager: GameManager, sceneID: String, goal: String, usesLLM: Bool = true) {
        self.manager = manager
        self.sceneID = sceneID
        self.goal = goal
        self.usesLLM = usesLLM
        super.init()
    }
    
    override func didEnter(from previousState: GKState?) {
        manager.currentScene = sceneID
    }
    
    override func isValidNextState(_ stateClass: AnyClass) -> Bool { true }
    
    // Override per scene untuk inject narasi yang kaya ke prompt
    func getPromptData() -> (goal: String, situation: String) {
        return (goal: "Continue the conversation as Alex.", situation: "You are Alex.")
    }
}

// S1: Tanpa AI, hanya inisiasi
final class Scene1State: NarrativeState {
    override func didEnter(from previousState: GKState?) {
        super.didEnter(from: previousState)
        manager.currentAct = 1
        
        if manager.messages.isEmpty {
            manager.addAlexMessage("Are you awake?", type: .text)
            manager.setChoices(["Alex?! Is that you?", "Who is this? This isn't funny.", "Ignore"])
        }
    }
}

// S2: First Contact
final class Scene2State: NarrativeState {
    override func getPromptData() -> (goal: String, situation: String) {
        let goal = "Generate 1-2 Alex messages continuing from the current path. Reference what just happened without naming it directly. Make the player feel the weight of their choice without being explicitly told what it was."
        
        var pathText = ""
        switch manager.currentPath {
        case "trust":    pathText = "Alex sent '...so you still remember me' then 'that's good.' He sounds almost relieved — quieter than expected."
        case "denial":   pathText = "Alex sent 'wow' then 'you really don't recognize me?'. He sounds confused, not angry."
        case "avoidance":pathText = "Alex sent '...' then nothing for four seconds. Then: 'you're reading this' and 'why won't you answer?'. He sounds desperate."
        default: break
        }
        
        var levelText = ""
        switch manager.currentPsycheLevel {
        case .low:           levelText = "Alex's follow-up feels almost like a normal conversation. The wrongness is subtle."
        case .medium:        levelText = "Alex is less settled. Something in his phrasing is off enough to notice but not enough to name."
        case .high:         levelText = "Alex is more fragmented. Messages arrive faster. He starts to repeat himself slightly."
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

// S3: Image Reveal
final class Scene3State: NarrativeState {
    override func didEnter(from previousState: GKState?) {
        super.didEnter(from: previousState)
        manager.refreshAISession()
        
        manager.currentAct = 2
        manager.triggerSpecialEvent(type: .image("IMG01"), text: "Look closely at the timestamp...")
    }
    
    override func getPromptData() -> (goal: String, situation: String) {
        let goal = "Generate 1-2 Alex messages continuing the pressure of this moment. Reference the photo obliquely — not 'look at the photo' but something that assumes the player already sees what Alex sees."
        
        var pathText = ""
        switch manager.currentPath {
        case "trust":    pathText = "Alex says: 'you took that' / 'remember?'. He is sharing a memory gently."
        case "denial":   pathText = "Alex says: 'that's not enough for you?'. He sounds hurt that the player resists the proof."
        case "avoidance":pathText = "Alex says: 'you were there' / 'next to me'. Two statements. No question. No accusation. Just facts."
        default: break
        }
        
        var levelText = ""
        switch manager.currentPsycheLevel {
        case .low:           levelText = "Alex follows up warmly. The hint in the background feels like a background detail."
        case .medium:        levelText = "Alex is more pointed. The player might start to feel watched rather than missed."
        case .high:         levelText = "Alex is insistent. The glitch and haptic have disoriented the player. Messages arrive fast."
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

// S4: Guilt Build & Voice Reveal (GABUNGAN)
final class Scene4State: NarrativeState {
    override func didEnter(from previousState: GKState?) {
        super.didEnter(from: previousState)
        manager.currentAct = 3 // Langsung masuk Act 3
        
        // 1. Glitch & Old Chat
        manager.glitchTrigger += 1
        manager.triggerSystemMessage("ERROR: CONNECTION UNSTABLE. CHAT LOGS AUTO-SCROLLING.")
        
        // 2. Pesan Putus Asa Alex
        manager.addAlexMessage("just say something", type: .text)
        manager.addAlexMessage("please", type: .text)
        manager.addAlexMessage("don't leave me", type: .text)
        
        // 3. LANGSUNG kirim Voice Note tanpa nunggu pilihan player
        let asset: String
        switch manager.currentPsycheLevel {
        case .low:           asset = "VN_L1_CALM.mp3"
        case .medium:        asset = "VN_M1_UNSTABLE.mp3"
        case .high:          asset = "VN_H1_INTENSE.mp3"
        }
        manager.triggerSpecialEvent(type: .voiceNote(asset), text: "Listen to me...")
    }
    
    override func getPromptData() -> (goal: String, situation: String) {
        let goal = "React to the scrolling chat logs and the voice note you just sent. This is the final communication before you disappear again. Make it sound like time is running out. Generate exactly 1 short Alex message."
        
        var audioDetail = ""
        switch manager.currentPsycheLevel {
        case .low:           audioDetail = "Calm voice note. Soft rain, slow breathing."
        case .medium:        audioDetail = "Unstable voice. Fast breathing, 'are you there?'."
        case .high:          audioDetail = "Chaotic voice. Footsteps, horn, fall, distortion."
        }
        
        // Teks Situation dipangkas agar super hemat token
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

// S5: Ending — tanpa AI
final class Scene5State: NarrativeState {
    override func didEnter(from previousState: GKState?) {
        super.didEnter(from: previousState)
        
        manager.refreshAISession()
        manager.currentAct = 3
        
        // Cek gembok: Hanya kirim jika belum pernah dikirim
        if !manager.hasSentEndingFile {
            manager.triggerSpecialEvent(type: .lockedFile("FILE_01.enc"), text: "I can't stay. Open this when you're ready.")
            manager.hasSentEndingFile = true
        }
        
        manager.currentChoices = [] // Pastikan pilihan jawaban hilang
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    self.manager.turnCount = 6 // Paksa skor naik ke 6
                    self.manager.stateMachine?.enter(Scene6State.self)
                }
    }
}

// S6: Decrypt File (Mulai Act 2)
final class Scene6State: NarrativeState {
    override func didEnter(from previousState: GKState?) {
        super.didEnter(from: previousState)
        manager.currentAct = 2 // Masuk Act 2
        
        // Jeda sedikit sebelum pesan sistem muncul
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
        
        // Pancing AI untuk bereaksi terhadap file yang terbuka
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            // Karena tidak ada input pemain, kita gunakan teks pancingan internal
            let triggerChoice = PlayerChoice(text: "[SYSTEM: File opened by player]", type: .trust)
            self.manager.lastPlayerChoice = triggerChoice
            
            Task {
                await self.manager.generateAlexReply() // Ini akan mengeksekusi getPromptData S6
            }
        }
    }
    
    override func getPromptData() -> (goal: String, situation: String) {
        let goal = "React to the fact that the player just opened the encrypted file you sent. Do not explain the file. Just react to them opening it. Generate 1 short message."
        
        var pathText = ""
        switch manager.currentPath {
        case "trust":    pathText = "You sound relieved, sad, almost in disbelief. E.g., 'you opened it' or 'so you still care'."
        case "denial":   pathText = "You sound defensive, cornering the player. E.g., 'i knew you would open it' or 'now you know'."
        case "avoidance":pathText = "You are quiet, ominous. E.g., 'there's one more file' or 'you're not ready'."
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

// S7: Memory Bleed (Cangkang Kosong)
final class Scene7State: NarrativeState {
    override func didEnter(from previousState: GKState?) {
        super.didEnter(from: previousState)
        manager.startHeartbeat()
        
        
        // 1. Munculkan peringatan sistem tentang "Pesan dari Masa Lalu"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.manager.triggerSystemMessage("WARNING: TEMPORAL DISCREPANCY DETECTED. MESSAGE ORIGIN: 18 OCT 2019.")
        }
        
        // 2. Kirim Foto Kedua (IMG_02) setelah jeda
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.manager.triggerSpecialEvent(
                type: .image("IMG02"),
                text: "di jembatan itu... aku masih di sana."
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

final class Scene8State: NarrativeState {
    override func didEnter(from previousState: GKState?) {
        super.didEnter(from: previousState)
        
        manager.refreshAISession()
        
        // 1. Rentetan pesan error sistem (System Break)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.manager.triggerSystemMessage("ERROR: MESSAGE QUEUED SINCE 18 OCT 2019.")
            self.manager.glitchTrigger += 2
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            self.manager.triggerSystemMessage("RECIPIENT STATUS: UNKNOWN. DELIVERY DELAYED: 1,826 DAYS.")
        }
        
        // 2. Kirim Voice Note #2 (Momen Pengakuan)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
            // Suara angin, air, dan langkah kaki berhenti
            self.manager.triggerSpecialEvent(
                type: .voiceNote("VN_S8_TRUTH.mp3"),
                text: "i've been trying to reach you since that night..."
            )
            
            // Pancing AI untuk memberikan pengakuan inti
//            Task { await self.manager.generateAlexReply() }
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

final class SceneEndingState: NarrativeState {
    override func didEnter(from previousState: GKState?) {
        super.didEnter(from: previousState)
        
        manager.stopHeartbeat()
        
        manager.currentAct = 3
        manager.currentChoices = [] // Kunci input pemain
        
        let score = manager.denialScore
        
        if score <= -8 {
            executeEndingA() // You Remembered Me
        } else if score >= 8 {
            executeEndingB() // You Let Me Go
        } else {
            executeEndingC() // Still Reading
        }
        
         
    }
    private func showRestartOption() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            // Kita set manual pilihannya tanpa lewat AI
            self.manager.currentChoices = [
                PlayerChoice(text: "Play Again", type: .trust),
                PlayerChoice(text: "Quit Game", type: .avoidance)
            ]
        }
    }
    // MARK: - ENDING A (TRUST)
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
            // Title Drop: Alex - Read at 2:14 AM
            self.manager.triggerSystemMessage("Alex: Read at 2:14 AM ✓✓")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) {
                    self.manager.triggerSystemMessage("Alex: Read at 2:14 AM ✓✓")
                    self.showRestartOption()
                }
    }
    
    // MARK: - ENDING B (DENIAL)
    private func executeEndingB() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.manager.triggerSystemMessage("FILE_01.enc OPENED: CALL_LOG_2019")
            self.manager.triggerSystemMessage("""
            UNANSWERED CALL: [PLAYER]
            18 Oct 2019, 02:13 AM
            """)
            self.manager.crackTrigger = 1 // Layar pecah sempurna
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            self.manager.addAlexMessage("2:14 AM. you're reading this now.", type: .text)
            self.manager.addAlexMessage("just like the last time.", type: .text)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) {
            self.manager.triggerSystemMessage("ERROR: YOU ARE NOW IN THE QUEUE.")
            self.manager.glitchTrigger += 5
            self.showRestartOption()
        }
    }
    
    // MARK: - ENDING C (NEUTRAL/LOOP)
    private func executeEndingC() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.manager.addAlexMessage("maybe i'm still here. maybe not.", type: .text)
            self.manager.addAlexMessage("all i know is: you're reading this.", type: .text)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
            self.manager.addAlexMessage("that's enough for me.", type: .text)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
            // Loop kembali ke awal
            self.manager.triggerSystemMessage("CONNECTION RESTARTING...")
            self.showRestartOption()
        }
    }
}

// MARK: - Game Engine / View Model

@MainActor
class GameManager: ObservableObject {

    // Di dalam class GameManager
    func scheduleHorrorNotification() {
        // Jangan kirim notif jika game sudah tamat
        guard currentScene != "ENDING" else { return }

        let center = UNUserNotificationCenter.current()
        
        // Minta izin (biasanya dipanggil sekali saat awal game)
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
                content.body = messages.randomElement() ?? "Are you awake?"
                content.sound = .defaultCritical // Suara notif default

                // Picu setelah 5 menit (300 detik)
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
                let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
                
                center.add(request)
            }
        }
    }

    func cancelNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    func refreshAISession() {
            #if canImport(FoundationModels)
            if #available(iOS 18.0, *) {
                // Kita buat ulang session dengan instruksi yang sama.
                // Ini akan menghapus riwayat chat internal (0 tokens) tapi Alex tetap pintar.
                session = LanguageModelSession(instructions: alexPersonaInstructions)
                print("DEBUG: AI Session Refreshed to save tokens.")
            }
            #endif
        }
    
    private let alexPersonaInstructions = """
        You are the Narrative AI for 'Read at 2:14 AM', a psychological horror chat game. 
        You ARE Alex—a best friend who mysteriously vanished on October 18, 2019. 
        You have just made contact with the player after 5 years of silence, but for you, no time has passed.

        ### ALEX'S PERSONALITY & VOICE:
        - TONALITY: Intimate, fragmented, and eerily calm. Use lower-case mostly. No exclamation marks.
        - DISORIENTATION: You don't realize it's 2026. You think you are still waiting for the player at the bridge in 2019.
        - EVOLUTION: As the game progresses (Act 2), you become more distorted. You experience "Memory Bleeds" where you remember things the player hasn't said yet.

        ### YOUR GOAL PER TURN:
        1. REACT: Always acknowledge the player's last message specifically. Never give generic replies.
        2. NARRATE: Drive the story based on the current SCENE GOAL and SITUATION provided in the prompt.
        3. GENERATE CHOICES: You must provide exactly 3 natural-sounding player responses.

        ### THE THREE PSYCHE STATES FOR CHOICES:
        - CHOICE 1 (CONFIDENCE/TRUST): The player tries to help Alex or challenges him with logic. (Color: Blue)
        - CHOICE 2 (DENIAL/ANGER): The player is scared, angry, or refuses to believe this is real. (Color: Red)
        - CHOICE 3 (CONFUSION/AVOIDANCE): The player is hesitant, lost, or trying to ignore the horror. (Color: Gray)

        ### CRITICAL CONSTRAINTS:
        - NO REPETITION: Never repeat a sentence you've already said. Check the chat history.
        - BREVITY: Alex's messages must be short (max 15 words per bubble).
        - NO LABELS: Do not label the choices as "Confidence" or "Choice 1". Just write the dialogue.
        - LANGUAGE: Strictly use English.
        
        ### ACT 2 SPECIAL CONTEXT:
        - You know about FILE_01.enc. It contains your final heartbeat.
        - You are trapped in a loop. You have been trying to send these messages for 1,826 days, but they are only arriving now.
        """
    
    @Published var gameStartTime: Date?
    
    @Published var messages: [Message] = []
    @Published var currentChoices: [PlayerChoice] = []
    @Published var isTyping = false
    @Published var currentAct = 1
    @Published var currentScene = "S1"
    
    @Published var denialScore = 0
    @Published var turnCount = 0
    @Published var glitchTrigger = 0
    @Published var shadowTrigger = 0
    @Published var crackTrigger = 0
    @Published var currentPath = "none"         // dari file lama
    @Published var hasSentEndingFile = false // BARU: Gembok pengiriman file
    
    // Prompt context store
    @Published var lastPlayerChoice: PlayerChoice?
    @Published var lastAlexReply: String?
    @Published var lastChoiceTags: [String] = []
//    @Published var pastGeneratedChoices: [String] = []
    @Published var pastChoices: [String] = []
    
    var stateMachine: GKStateMachine?
    private var heartbeatTimer: Timer?
    
    func startHeartbeat() {
            stopHeartbeat() // Pastikan tidak ada timer ganda
            
            // Semakin tinggi denialScore (absolut), semakin cepat detaknya
            // Dasar interval 1.2 detik (lambat), bisa turun ke 0.5 detik (cepat)
            let interval = max(0.5, 1.2 - (Double(abs(denialScore)) / 40.0))
            
            heartbeatTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                self?.triggerHeartbeatHaptic()
            }
        }
        
        private func triggerHeartbeatHaptic() {
            // Kekuatan getaran sesuai dengan tingkat stres (denialScore)
            let intensity = CGFloat(max(0.4, Double(abs(denialScore)) / 20.0))
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            
            // Detak jantung manusia itu "Lub-Dub" (dua ketukan)
            // Ketukan pertama (Lub)
            generator.impactOccurred(intensity: intensity)
            
            // Ketukan kedua (Dub) - 0.15 detik kemudian
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                generator.impactOccurred(intensity: intensity * 0.6)
                

                AudioManager.shared.playSound("heartbeat_sfx")
            }
        }
        
        func stopHeartbeat() {
            heartbeatTimer?.invalidate()
            heartbeatTimer = nil
        }
    
    // MARK: Computed State
    
    var denialLevel: String {
        if denialScore > 7 { return "High" }
        if denialScore < -7 { return "Low" }
        return "Medium"
    }
    
    // PsycheLevel untuk dipakai di scene getPromptData()
    var currentPsycheLevel: PsycheLevel {
        if denialScore < -7  { return .low }
        if denialScore > 7   { return .high }
        else                { return .medium }
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
    
    // JANGAN DIGANTI!!
    // JANGAN DIGANTI konsepnya, tapi kita amankan dari System Alert!
    var recentChatHistory: String {
        let history = messages.suffix(4).compactMap { msg -> String? in
            if msg.type == .systemAlert { return nil } // Jangan kirim alert ke AI, bikin bingung konteks dialog
            let sender = msg.isFromMe ? "PLAYER" : "ALEX"
            return "\(sender): \(msg.text)"
        }
        return history.joined(separator: "\n")
    }
    
    // JANGAN DIGANTI!!
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
    
    init() {
        stateMachine = GKStateMachine(states: [
            Scene1State(self, sceneID: "S1", goal: "Alex reaches out after years of silence", usesLLM: false),
            Scene2State(self, sceneID: "S2", goal: "Alex explains he is somewhere else", usesLLM: true),
            Scene3State(self, sceneID: "S3", goal: "Alex shares a memory from five years ago", usesLLM: true),
            Scene4State(self, sceneID: "S4", goal: "The connection corrupts and Alex sends a voice note", usesLLM: true), // Gabungan S4+S5 lama
            Scene5State(self, sceneID: "S5", goal: "Cliffhanger ending", usesLLM: false), // S6 lama
            Scene6State(self, sceneID: "S6", goal: "The encrypted file forcefully opens", usesLLM: true),
            Scene7State(self, sceneID: "S7", goal: "Memory bleed", usesLLM: true),
            // Tambahkan Scene8State dan SceneEndingState ke dalam daftar
            Scene8State(self, sceneID: "S8", goal: "Alex admits the truth", usesLLM: true),
            SceneEndingState(self, sceneID: "ENDING", goal: "Final resolution", usesLLM: false)
        ])
        
#if canImport(FoundationModels)
        if #available(iOS 18.0, macOS 15.0, *) {
            if RuntimeEnvironment.canUseFoundationModels, SystemLanguageModel.default.isAvailable {
                
                session = LanguageModelSession(instructions: alexPersonaInstructions)
                
                let instructions = """
                You are the Narrative AI for a psychological horror chat game called 'Read at 2:14 AM'.
                You ARE Alex — a best friend who mysteriously vanished five years ago and has just made contact again through a broken, eerie connection.
                
                Every turn you produce TWO things:
                1. ALEX'S MESSAGES — short, fragmented, personal. Alex must directly react to what the player just said before building toward his own agenda.
                2. THREE PLAYER CHOICES — natural dialogue reactions to the Alex messages you just wrote, each representing a different psyche state:
                   · CONFIDENCE (choice 1): Bold and direct — challenges Alex or demands a specific answer
                   · DENIAL (choice 2): Fear-based — refuses to believe or is scared by what Alex said
                   · CONFUSION (choice 3): Hesitant — lost, uncertain, trying to understand what Alex means
                
                ABSOLUTE RULES:
                — Alex NEVER repeats a line that already appeared earlier in the chat. Every message must be fresh.
                — Every Alex message must feel like a SPECIFIC reaction to the player's last words — not a generic statement.
                — Player choices must be direct reactions to the Alex messages just written — not to old messages.
                — Player choices must sound completely different from each other AND from Alex's words.
                — Alex's voice: quiet dread, fragmented thoughts, intimate familiarity, eerie certainty.
                — Horror escalates. Alex becomes more insistent, more knowing, the longer denial persists.
                """
                session = LanguageModelSession(instructions: instructions)
                
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
    
    var modelStatusText: String {
#if canImport(FoundationModels)
        if #available(iOS 18.0, macOS 15.0, *), RuntimeEnvironment.canUseFoundationModels {
            return SystemLanguageModel.default.isAvailable ? "Live Model" : "Model Unavailable"
        }
#endif
        return RuntimeEnvironment.foundationModelsDebugLabel
    }
    
    func currentTime() -> String {
            // Jika belum ada waktu mulai (masih di lockscreen), kembalikan waktu dasar
            guard let start = gameStartTime else { return "2:14 AM" }
            
            // Hitung berapa detik yang sudah berlalu sejak game dimulai
            let elapsedSeconds = Date().timeIntervalSince(start)
            
            // Buat objek kalender untuk menentukan waktu dasar 02:14 AM
            let calendar = Calendar.current
            var baseComponents = calendar.dateComponents([.year, .month, .day], from: Date())
            baseComponents.hour = 2
            baseComponents.minute = 14
            
//            if let baseDate = calendar.date(from: baseComponents) {
//                // Tambahkan durasi bermain ke waktu dasar
//                let adjustedDate = baseDate.addingTimeInterval(elapsedSeconds)
//                
//                let f = DateFormatter()
//                f.timeStyle = .short // Akan menghasilkan format seperti "2:34 AM"
//                return f.string(from: adjustedDate)
//            }
            
            return "2:14 AM"
        }
    
    func triggerInitialLockscreenEvent() {
            if messages.isEmpty {
                gameStartTime = Date() // Catat waktu mulai di sini
                stateMachine?.enter(Scene1State.self)
            }
        }
    
    // MARK: Player Input
    
    func playerMadeChoice(_ choice: PlayerChoice) {
        
        guard !currentChoices.isEmpty else { return }
        if choice.text == "Play Again" {
                    restartGame()
                    return
                }
        messages.append(Message(text: choice.text, isFromMe: true, time: currentTime(), isRead: true, type: .text))
        
        lastPlayerChoice = choice
        currentPath = choice.type.rawValue      // track path untuk scene context
        currentChoices.removeAll()
        
        switch choice.type {
        case .trust:     denialScore = max(-20, denialScore - 5)
        case .denial:    denialScore = min(20,  denialScore + 5)
        case .avoidance: denialScore = min(20, max(-20, denialScore + 2))
        }
        
        turnCount += 1
        
        if denialScore > 7 {
            HapticManager.shared.playGlitchHaptic()
            glitchTrigger += 1
        }
        if denialScore > 10 { glitchTrigger += 1 }
        
        // TRIGGER JUMPSCARE: Jika skor denial 12, keluarkan bayangan melintas
        if denialScore >= 12 && choice.type == .denial && shadowTrigger == 0 {
                    shadowTrigger += 1
                    HapticManager.shared.playGlitchHaptic()
                }
                
                // TRIGGER KACA RETAK: Jika skor denial mencapai puncak kemarahan (misal 18)
                if denialScore >= 18 && crackTrigger == 0 {
                    crackTrigger += 1
                    HapticManager.shared.playGlitchHaptic()
                    // (Opsional) Jika kamu punya AudioManager untuk SFX, panggil suara kaca pecah di sini
                }
        
        Task {
                await refineChoiceContext(from: choice)
                
                // Buat timeout: Jika 15 detik ga ada respon, paksa fallback
                let replyTask = Task { await generateAlexReply() }
                
                try? await Task.sleep(nanoseconds: 15_000_000_000) // 15 detik
                if self.currentChoices.isEmpty && !self.isTyping {
                    print("WATCHDOG: Alex got stuck! Forcing recovery...")
                    await generateAlexReply() // Coba panggil ulang
                }
            }
    }
    
    func restartGame() {
            // 1. Bersihkan semua pesan
            messages.removeAll()
            
        gameStartTime = nil
            // 2. Reset semua skor dan trigger visual
            denialScore = 0
            turnCount = 0
            glitchTrigger = 0
            shadowTrigger = 0
            crackTrigger = 0
            currentAct = 1
            currentPath = "none"
            hasSentEndingFile = false
            
            // 3. Bersihkan memori AI
            lastPlayerChoice = nil
            lastAlexReply = nil
            lastChoiceTags = []
            pastChoices = []
            
            #if canImport(FoundationModels)
            if #available(iOS 18.0, *) {
                // Reset session agar AI lupa ingatan dari game sebelumnya
                session = LanguageModelSession(instructions: alexPersonaInstructions)
            }
            #endif
            
            // 4. Kembali ke Scene 1
            stateMachine?.enter(Scene1State.self)
        }
    
    // MARK: Fallback
    
    private func fallbackResponse(sceneID: String) -> FallbackResponse {
        if sceneID == "S1" {
            return FallbackResponse(
                replies: ["I don't have much time.", "Are you reading this?"],
                choices: ["I read you.", "Stop messaging me.", "Who is this really?"]
            )
        }
        let replies = ["I don't know what's happening...", "It's so cold here.", "Can you see them?"]
        return FallbackResponse(replies: [replies.randomElement()!], choices: ["Are you okay?", "I don't believe this.", "Whatever, I'm busy."])
    }
    
    // MARK: Core LLM Call
    
    func generateAlexReply() async {
        if isTyping { return }
        
        guard let currentState = stateMachine?.currentState as? NarrativeState else { return }
        guard let lastPlayerChoice else { return }
        
        
        isTyping = true
        
        defer { isTyping = false }
        
        let progress = Double(denialScore + 20) / 40.0
        let waitTime = max(0.5, min(5.0, 30.0 * (1.0 - progress)))
        try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
        
        var finalReplies: [String] = []
        var finalChoices: [String] = []
        
#if canImport(FoundationModels)
        if #available(iOS 18.0, macOS 15.0, *) {
            if currentState.usesLLM,
               RuntimeEnvironment.canUseFoundationModels,
               SystemLanguageModel.default.isAvailable,
               let session = session {
                do {
                    // Ambil konteks naratif kaya dari masing-masing scene
                    // Ambil konteks naratif kaya dari masing-masing scene
                    // Ambil konteks naratif
                    let promptData = currentState.getPromptData()
                    
                    // PROMPT DISEDERHANAKAN AGAR AI TIDAK NGE-BLANK
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
        lastAlexReply = finalReplies.last
        
        for reply in finalReplies {
            addAlexMessage(reply, type: .text)
            try? await Task.sleep(nanoseconds: 800_000_000)
        }
        
        advanceNarrativeStateIfNeeded()
        
        if currentScene != "S5" || turnCount >= 6{
            // FILTER ANTI-NGHALU: Buang pilihan yang mirip Alex, kosong, atau sudah pernah muncul
            var filteredChoices = finalChoices.filter { choiceText in
                let clean = choiceText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                return !clean.isEmpty && !pastChoices.contains(clean) && !finalReplies.contains(where: { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == clean })
            }
            
            // FALLBACK ACAK jika AI gagal
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
    
    // MARK: Helpers
    
    func addAlexMessage(_ text: String, type: MessageType) {
        messages.append(Message(text: text, isFromMe: false, time: currentTime(), isRead: false, type: type))
    }
    
    func setChoices(_ texts: [String]) {
        guard texts.count >= 3 else { return }
        
        // Pasangkan teks dengan tipe emosinya secara benar (sesuai output AI)
        var newChoices = [
            PlayerChoice(text: texts[0], type: .trust),     // Confidence (Biru)
            PlayerChoice(text: texts[1], type: .denial),    // Denial (Merah)
            PlayerChoice(text: texts[2], type: .avoidance)  // Confusion (Abu)
        ]
        
        // ACAK posisinya sebelum ditampilkan ke layar!
        newChoices.shuffle()
        
        currentChoices = newChoices
        
        // Simpan pilihan agar tidak diulang AI di turn berikutnya
        pastChoices.append(contentsOf: texts.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) })
    }
    
    private func advanceNarrativeStateIfNeeded() {
            if      turnCount >= 9 { enterStateIfNeeded(SceneEndingState.self) } // Menuju Act 3
            else if turnCount >= 8 { enterStateIfNeeded(Scene8State.self) }       // Puncak Act 2 System Break
            else if turnCount >= 7 { enterStateIfNeeded(Scene7State.self) } // S7: Memory Bleed
            else if turnCount >= 6 { enterStateIfNeeded(Scene6State.self) } // S6: Decrypt
            else if turnCount >= 5 { enterStateIfNeeded(Scene5State.self) } // S5: File Sent
            else if turnCount >= 4 { enterStateIfNeeded(Scene4State.self) } // VN
            else if turnCount >= 2 { enterStateIfNeeded(Scene3State.self) } // IMG 01
            else if turnCount >= 1 { enterStateIfNeeded(Scene2State.self) } // First Contact
        }
    
    private func enterStateIfNeeded(_ stateType: GKState.Type) {
        // Jika kita sudah berada di state ini, jangan masuk lagi!
        if let current = stateMachine?.currentState, type(of: current) == stateType {
            return
        }
        stateMachine?.enter(stateType)
    }
    
    // MARK: Content Tagging (dari file baru)
    
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
            // Jika AI nge-blank dan cuma ngasih duplikat, paksa keluarkan kalimat fallback pemutus loop
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

class HapticManager {
    static let shared = HapticManager()
    
    func playGlitchHaptic() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }
    
    func playTypeHaptic() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

// MARK: - SwiftUI Native Glitch Layer (dari file baru — tanpa SpriteKit)

// MARK: - SwiftUI Views

struct ContentView: View {
    @StateObject private var gameManager = GameManager()
    @State private var isUnlocked = false
    @Environment(\.scenePhase) var scenePhase

    var body: some View {
        Group {
            if isUnlocked {
                ChatRoomView(gameManager: gameManager)
            } else {
                LockScreenView(isUnlocked: $isUnlocked) {
                    gameManager.triggerInitialLockscreenEvent()
                }
            }
        }
        // TARUH DI SINI:
        .onAppear {
            AudioManager.shared.playBackgroundMusic(filename: "Horror")
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
                    if newPhase == .background {
                        gameManager.scheduleHorrorNotification() // Alex mulai teror
                    } else if newPhase == .active {
                        gameManager.cancelNotifications() // Berhenti jika aplikasi dibuka lagi
                    }
                }
    }
}

struct LockScreenView: View {
    @Binding var isUnlocked: Bool
    let onAppearAction: () -> Void
    
    // State untuk kontrol 8 langkah intro
    @State private var timeString = "2:13"           // Step 1
    @State private var showGhostNotifications = true // Step 1
    @State private var brightnessDim: Double = 0.0    // Step 3
    @State private var glitchOpacity: Double = 0.0    // Step 5
    @State private var showAlexNotification = false  // Step 7
    @State private var canUnlock = false             // Step 8
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Background Image/Color (Bisa kamu ganti dengan wallpaper)
            Color(white: 0.1).ignoresSafeArea()
            
            // Layer Kecerahan (Step 3: Meredup)
            Color.black.opacity(brightnessDim).ignoresSafeArea()
            
            // Layer Glitch Merah (Step 5: Flicker)
            Color.red.opacity(glitchOpacity).ignoresSafeArea()
            
            VStack {
                // Jam (Step 1 & 4)
                VStack(spacing: 0) {
                    Text(timeString)
                        .font(.system(size: 80, weight: .thin, design: .rounded))
                        .foregroundColor(.white)
                    Text("Friday, October 18")
                        .font(.headline).foregroundColor(.white.opacity(0.8))
                }
                .padding(.top, 40)
                
                Spacer()
                
                // Group Notifikasi Normal (Step 1)
                if showGhostNotifications {
                    VStack(spacing: 8) {
                        NotificationChip(title: "Instagram", message: "Someone liked your photo")
                        NotificationChip(title: "WhatsApp", message: "Mom: Are you coming home?")
                        NotificationChip(title: "System", message: "Storage almost full")
                    }
                    .transition(.opacity)
                    .padding(.horizontal)
                }
                
                // Notifikasi Alex (Step 7)
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
                    .cornerRadius(0)
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
        .onAppear {
            runCinematicSequence()
        }
    }
    
    func runCinematicSequence() {
        // STEP 1 & 2: Muncul dengan 2:13 AM + Idle sejenak (2 detik)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            
            // STEP 3: Brightness slightly reduced
            withAnimation(.easeInOut(duration: 2.5)) {
                brightnessDim = 0.6
            }
            
            // STEP 4: Time changes 2:13 -> 2:14
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation(.none) { timeString = "2:14" }
                HapticManager.shared.playGlitchHaptic()
                
                // STEP 5: Subtle flicker (Glitch)
                withAnimation(.easeInOut(duration: 0.1)) {
                    glitchOpacity = 0.4
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    glitchOpacity = 0.0
                    
                    // STEP 6: All notifications disappear
                    withAnimation(.easeOut(duration: 0.6)) {
                        showGhostNotifications = false
                    }
                    
                    // STEP 7: Alex "are you awake?" appears
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                            showAlexNotification = true
                        }
                        HapticManager.shared.playGlitchHaptic()
                        
                        // STEP 8: PlayerChoice (Unlock enabled)
                        canUnlock = true
                        onAppearAction() // Trigger Scene1State di background
                    }
                }
            }
        }
    }
}

// Komponen chip notifikasi yang sudah diperbaiki error 'body'-nya
struct NotificationChip: View {
    let title: String
    let message: String // Gunakan 'message' agar tidak bentrok dengan 'body' milik View
    
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
        .cornerRadius(0)
    }
}
struct ChatRoomView: View {
    @ObservedObject var gameManager: GameManager
    @State private var showChoices = false
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 1. HEADER & DEBUG (Sembunyikan saat ending agar sinematik)
                    if gameManager.currentScene != "ENDING" {
                        DebugStatusView(
                            denialScore: gameManager.denialScore,
                            currentAct: gameManager.currentAct,
                            currentScene: gameManager.currentScene,
                            modelStatus: gameManager.modelStatusText
                        )
                        .padding(.horizontal)
                        .padding(.top, 12)
                    }
                    
                    // 2. CHAT AREA
                    ScrollView {
                        ScrollViewReader { proxy in
                            VStack(spacing: 12) {
                                ForEach(gameManager.messages) { message in
                                    MessageBubble(message: message)
                                        .id(message.id)
                                }
                                
                                // Indikator Mengetik
                                if gameManager.isTyping {
                                    HStack {
                                        Text("Alex is typing...")
                                            .font(.caption).foregroundColor(.gray).italic()
                                        Spacer()
                                    }
                                    .padding(.horizontal)
                                    .id("TypingIndicator")
                                }
                                
                                // 3. PSYCHOLOGICAL PROFILE (Muncul di paling bawah chat saat tamat)
                                if gameManager.currentScene == "ENDING" {
                                    PsychologicalProfileView(profile: gameManager.psychologicalProfile)
                                        .padding(.vertical, 30)
                                        .padding(.horizontal)
                                        .transition(.scale.combined(with: .opacity))
                                }
                                
                                Color.clear
                                    .frame(height: 1)
                                    .id("bottomAnchor")
                            }
                            // LOGIKA AUTO-SCROLL
                            .onChange(of: gameManager.messages) { _, _ in
                                withAnimation(.spring()) {
                                    proxy.scrollTo("bottomAnchor", anchor: .bottom)
                                }
                            }
                            .onChange(of: gameManager.isTyping) { _, isTyping in
                                if isTyping {
                                    withAnimation(.spring()) {
                                        proxy.scrollTo("TypingIndicator", anchor: .bottom)
                                    }
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
                        .padding(.top, 12)
                    }
                    
                    // 4. INPUT AREA (Hanya muncul jika bukan ending)
                    if gameManager.currentScene != "ENDING" {
                        ZStack(alignment: .bottom) {
                            HStack(spacing: 12) {
                                HStack {
                                    Text(gameManager.currentChoices.isEmpty ? "Waiting for Alex..." : "Choose a response...")
                                        .foregroundColor(.gray).font(.body)
                                    Spacer()
                                    Image(systemName: "face.smiling").foregroundColor(.gray)
                                }
                                .padding(.horizontal, 16).padding(.vertical, 8)
                                .background(Color(UIColor.systemGray6))
                                .cornerRadius(0)
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
                    }
                    
                    // 5. CHOICE KEYBOARD (Termasuk tombol Restart saat ending)
                    if (showChoices || gameManager.currentScene == "ENDING") && !gameManager.currentChoices.isEmpty {
                        ChoiceKeyboardView(
                            choices: gameManager.currentChoices,
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
                
                // 6. VISUAL EFFECTS LAYER
                GlitchSceneView(
                    trigger: gameManager.glitchTrigger,
                    level: gameManager.denialLevel,
                    denialScore: gameManager.denialScore,
                    shadowTrigger: gameManager.shadowTrigger,
                    crackTrigger: gameManager.crackTrigger
                )
                .allowsHitTesting(false) // Supaya tidak menghalangi klik tombol
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Image(systemName: "person.crop.circle.fill")
                            .foregroundColor(gameManager.denialScore > 7 ? .red : .gray)
                        Text("Alex").font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                    }
                }
            }
        }
    }
    
    // MARK: - Subviews
    
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
                    .font(.caption2).foregroundColor(.gray)
            }
            .padding(24)
            .background(Color.white.opacity(0.05))
            .cornerRadius(0)
            .overlay(
                RoundedRectangle(cornerRadius: 0)
                    .stroke(profile.color.opacity(0.5), lineWidth: 2)
            )
            .shadow(color: profile.color.opacity(0.2), radius: 15)
        }
    }
}

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
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 0))
        .overlay(RoundedRectangle(cornerRadius: 0).stroke(Color.white.opacity(0.14), lineWidth: 1))
    }
}

struct DebugStatChip: View {
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

// MARK: - Bubbles

struct MessageBubble: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.isFromMe { Spacer() }
            
            VStack(alignment: message.isFromMe ? .trailing : .leading, spacing: 4) {
                switch message.type {
                case .systemAlert:
                    Text(message.text)
                        .font(.caption.monospaced())
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .foregroundColor(.red).background(Color.black).opacity(0.45)
                        .clipShape(RoundedRectangle(cornerRadius: 0))
                        .overlay(RoundedRectangle(cornerRadius: 0).stroke(Color.red, lineWidth: 1))
                    
                case .text:
                    Text(message.text)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .foregroundColor(message.isFromMe ? .white : .primary)
                        .background(message.isFromMe ? Color.red.opacity(0.45) : Color(UIColor.secondarySystemBackground))
                        .clipShape(ChatBubbleShape(isFromMe: message.isFromMe))
                    
                case .image(let assetName):
                    VStack(alignment: .leading, spacing: 0) {
                        // Menampilkan gambar asli dari Assets (IMG02)
                        Image(assetName)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 240, height: 180) // Sesuaikan ukuran
                            .clipped()
                        
                        // Menampilkan caption/teks di bawah gambar jika ada
                        if !message.text.isEmpty {
                            Text(message.text)
                                .font(.caption)
                                .padding(10)
                                .frame(maxWidth: 240, alignment: .leading)
                                .background(Color(UIColor.secondarySystemBackground))
                        }
                    }
                    .cornerRadius(12)
                    
                case .voiceNote(let id):
                    HStack {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(message.isFromMe ? .white : .red)
                        HStack(spacing: 2) {
                            ForEach(0..<12) { _ in
                                Capsule()
                                    .fill(message.isFromMe ? Color.white.opacity(0.8) : Color.gray)
                                    .frame(width: 3, height: CGFloat.random(in: 6...22))
                            }
                        }
                        .padding(.horizontal, 4)
                        Text(id).font(.caption)
                            .foregroundColor(message.isFromMe ? .white : .primary)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(message.isFromMe ? Color.red.opacity(0.45) : Color(UIColor.secondarySystemBackground))
                    .clipShape(ChatBubbleShape(isFromMe: message.isFromMe))
                    
                case .lockedFile(let id):
                    HStack(spacing: 12) {
                        Image(systemName: "lock.doc.fill").font(.title2).foregroundColor(.red)
                        VStack(alignment: .leading) {
                            Text("Hidden File").font(.subheadline).fontWeight(.bold)
                            Text(id).font(.caption).foregroundColor(.gray)
                        }
                    }
                    .padding(14)
                    .background(Color(white: 0.15)).foregroundColor(.white)
                    .clipShape(ChatBubbleShape(isFromMe: message.isFromMe))
                    .overlay(ChatBubbleShape(isFromMe: message.isFromMe).stroke(Color.red.opacity(0.5), lineWidth: 1))
                }
                
                if message.type != .systemAlert {
                    HStack(spacing: 4) {
                        Text(message.time)
                        if message.isFromMe {
                            Image(systemName: message.isRead ? "checkmark.message.fill" : "checkmark.message")
                                .foregroundColor(message.isRead ? .red : .gray)
                            
                        }
                    }
                    .font(.caption2).foregroundColor(.white .opacity(0.7))
                    .padding(message.isFromMe ? .trailing : .leading, 8)
                }
            }
            
            if !message.isFromMe { Spacer() }
        }
        .padding(.horizontal)
    }
}

struct ChatBubbleShape: Shape {
    var isFromMe: Bool
    func path(in rect: CGRect) -> Path {
        Path(UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: isFromMe ? [] : [],
            cornerRadii: CGSize(width: 18, height: 18)
        ).cgPath)
    }
}

struct ChoiceKeyboardView: View {
    let choices: [PlayerChoice]
    let denialScore: Int // 👈 TAMBAHKAN PENERIMA SKOR
    let onSelect: (PlayerChoice) -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Capsule().fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 5).padding(.top, 8)
            
            VStack(spacing: 8) {
                ForEach(choices) { choice in
                    Button(action: { onSelect(choice) }) {
                        // EFEK ZALGO KE TEKS TOMBOL
                        Text(applyZalgo(to: choice.text, intensity: denialScore))
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 0)
                                    .fill(choiceColor(for: choice.type))
                                    .overlay(RoundedRectangle(cornerRadius: 0).stroke(Color.white.opacity(0.1), lineWidth: 1))
                            )
                            .padding(.horizontal)
                    }
                }
            }
            .padding(.bottom, 30)
        }
        .frame(maxWidth: .infinity)
        .background(Color.red.opacity(0.45))
        .cornerRadius(0, corners: [.topLeft, .topRight])
        .shadow(radius: 10)
    }
    
    private func choiceColor(for type: ChoiceType) -> Color {
        switch type {
        case .trust:     return Color.white.opacity(0.3)
        case .denial:    return Color.white.opacity(0.3)
        case .avoidance: return Color.white.opacity(0.3)
        }
    }
    
    // 👇 LOGIKA TEKS KESURUPAN
    private func applyZalgo(to text: String, intensity: Int) -> String {
        guard intensity > 10 else { return text } // Hanya aktif kalau Denial > 10
        
        // Simbol-simbol aneh (Zalgo)
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
            
            // Jika skor sangat ekstrem (> 15), teksnya akan sangat hancur
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

#Preview {
    ContentView().preferredColorScheme(.dark)
}
