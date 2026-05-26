import SwiftUI
import GameplayKit

// MARK: - GameplayKit Narrative States
// ─────────────────────────────────────────────────────────────────────────────
// Audit follow-ups:
// • Every dispatched closure is guarded by `manager.currentScene == sceneID`
//   so a game reset / scene jump between schedule-time and fire-time cannot
//   mutate the new game's state.
// • Scene 3/5/8 no longer call `manager.refreshAISession()`. Refreshing the
//   `LanguageModelSession` mid-game wiped Apple's internal transcript and
//   destroyed narrative continuity. The session now lives continuously across
//   one run; only `restartGame()` and `GameSaveManager.restore` rebuild it.

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

    /// Schedules `work` after `delay` seconds, but only fires it if the manager is
    /// still in this scene at fire-time. Prevents stale closures from mutating a
    /// new game session after restart/restore.
    func schedule(after delay: TimeInterval, _ work: @escaping () -> Void) {
        let expectedScene = sceneID
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak manager] in
            guard let manager, manager.currentScene == expectedScene else { return }
            work()
        }
    }
}

// MARK: Scene 1 — Initial contact (no AI)

final class Scene1State: NarrativeState {
    override func didEnter(from previousState: GKState?) {
        super.didEnter(from: previousState)
        guard !manager.isRestoringFromSave else { return }
        manager.armScene1OpeningIfNeeded()
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
        case .high:           levelText = "Alex is more fragmented. Messages arrive faster. He starts to repeat himself slightly."
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
        case .high:           levelText = "Alex is insistent. The glitch and haptic have disoriented the player. Messages arrive fast."
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
        case .high:           asset = "VN_H1.mp3"
        }
        manager.triggerSpecialEvent(type: .voiceNote(asset), text: "Listen to me...")
    }

    override func getPromptData() -> (goal: String, situation: String) {
        let goal = "React to the scrolling chat logs and the voice note you just sent. This is the final communication before you disappear again. Make it sound like time is running out. Generate exactly 1 short Alex message."

        var audioDetail = ""
        switch manager.currentPsycheLevel {
        case .low:            audioDetail = "Calm voice note. Soft rain, slow breathing."
        case .medium:         audioDetail = "Unstable voice. Fast breathing, 'are you there?'."
        case .high:           audioDetail = "Chaotic voice. Footsteps, horn, fall, distortion."
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
    /// How long the bridge cliffhanger holds before auto-advancing to Scene 6.
    /// Public-static so `GameSaveManager` can re-schedule the same delay on restore.
    static let bridgeAdvanceDelay: TimeInterval = 5.0

    override func didEnter(from previousState: GKState?) {
        super.didEnter(from: previousState)
        guard !manager.isRestoringFromSave else { return }
        EvidenceBoardManager.shared.unlockFragment(forScene: "S5")

        manager.currentAct = 2

        if !manager.hasSentEndingFile {
            manager.triggerSpecialEvent(type: .lockedFile("HIDDEN-FILE.zip"), text: "I can't stay. Open this when you're ready.")
            manager.hasSentEndingFile = true
        }

        manager.currentChoices = []
        manager.scheduleScene5BridgeAdvanceIfNeeded()
    }
}

// MARK: Scene 6 — Decrypt File / Act 2 Begin (AI)

final class Scene6State: NarrativeState {
    override func didEnter(from previousState: GKState?) {
        super.didEnter(from: previousState)
        guard !manager.isRestoringFromSave else { return }
        EvidenceBoardManager.shared.unlockFragment(forScene: "S6")

        schedule(after: 1.5) { [weak manager] in
            guard let manager else { return }
            let glitchText = """
            ERROR: HIDDEN-FILE.zip DECRYPTING...
            PROGRESS: 34%... 61%... 89%... INCOMPLETE
            PARTIAL CONTENTS AVAILABLE:

            "if you're reading this, you're too late."
            Loc: -6.2088, 106.8456
            Time: 18 Oct 2019, 02:14 AM
            """
            manager.triggerSystemMessage(glitchText)
        }

        schedule(after: 3.0) { [weak manager] in
            guard let manager else { return }
            let triggerChoice = PlayerChoice(text: "I opened the file.", type: .trust)
            manager.lastPlayerChoice = triggerChoice
            Task { await manager.generateAlexReply() }
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
        It revealed a note: "if you're reading this, you're too late." and the timestamp 02:14 AM.

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

        schedule(after: 1.0) { [weak manager] in
            manager?.triggerSystemMessage("WARNING: TEMPORAL DISCREPANCY DETECTED. MESSAGE ORIGIN: 18 OCT 2019.")
        }

        schedule(after: 3.0) { [weak manager] in
            manager?.triggerSpecialEvent(
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

        manager.currentAct = 3

        schedule(after: 1.0) { [weak manager] in
            guard let manager else { return }
            manager.triggerSystemMessage("ERROR: MESSAGE QUEUED SINCE 18 OCT 2019.")
            manager.glitchTrigger += 2
        }

        schedule(after: 2.5) { [weak manager] in
            manager?.triggerSystemMessage("RECIPIENT STATUS: UNKNOWN. DELIVERY DELAYED: 1,826 DAYS.")
        }

        schedule(after: 4.5) { [weak manager] in
            manager?.triggerSpecialEvent(
                type: .voiceNote("VN_H2.mp3"),
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
// The chapter-end UX (footer + "Coming soon" teaser) lives entirely in `ChatRoomView`
// so the scene only needs to wind down game state and mark the ending finished.

final class SceneEndingState: NarrativeState {
    override func didEnter(from previousState: GKState?) {
        super.didEnter(from: previousState)
        guard !manager.isRestoringFromSave else { return }
        EvidenceBoardManager.shared.unlockFragment(forScene: "ENDING")

        manager.stopHeartbeat()
        manager.currentAct = 3
        manager.currentChoices = []

        AppSettings.shared.totalClears += 1

        DispatchQueue.main.async {
            withAnimation { self.manager.isEndingFinished = true }
        }
    }
}
