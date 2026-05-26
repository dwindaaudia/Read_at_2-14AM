import Foundation
import GameplayKit

// MARK: - GAME SAVE SYSTEM

final class GameSaveManager {
    static let shared = GameSaveManager()
    private let key = "ra214_savedGameState"

    var hasSave: Bool {
        UserDefaults.standard.data(forKey: key) != nil
    }

    func save(from manager: GameManager) {
        guard manager.currentScene != "ENDING",
              !manager.messages.isEmpty else { return }

        let savedMessages = manager.messages.map { msg -> SavedGameState.SavedMessage in
            var typeKey = "text"
            var typePayload = ""
            switch msg.type {
            case .text:               typeKey = "text"
            case .systemAlert:        typeKey = "systemAlert"
            case .image(let name):    typeKey = "image";      typePayload = name
            case .voiceNote(let id):  typeKey = "voiceNote";  typePayload = id
            case .lockedFile(let id): typeKey = "lockedFile"; typePayload = id
            }
            return SavedGameState.SavedMessage(
                text: msg.text, isFromMe: msg.isFromMe,
                time: msg.time, typeKey: typeKey, typePayload: typePayload,
                isRead: msg.isRead
            )
        }

        let currentChoices = manager.currentChoices.map {
            SavedGameState.SavedChoice(text: $0.text, typeString: $0.type.rawValue)
        }
        let lastPlayerChoice = manager.lastPlayerChoice.map {
            SavedGameState.SavedChoice(text: $0.text, typeString: $0.type.rawValue)
        }

        let state = SavedGameState(
            denialScore:       manager.denialScore,
            turnCount:         manager.turnCount,
            currentScene:      manager.currentScene,
            currentAct:        manager.currentAct,
            currentPath:       manager.currentPath,
            hasSentEndingFile: manager.hasSentEndingFile,
            savedMessages:     savedMessages,
            savedDate:         Date(),
            currentChoices:    currentChoices,
            lastPlayerChoice:  lastPlayerChoice,
            pastChoices:       manager.pastChoices,
            trustCount:        manager.trustCount,
            denialCount:       manager.denialCount,
            avoidanceCount:    manager.avoidanceCount,
            glitchTrigger:     manager.glitchTrigger,
            shadowTrigger:     manager.shadowTrigger,
            crackTrigger:      manager.crackTrigger
        )

        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    @discardableResult
    func restore(into manager: GameManager) -> Bool {
        guard let data = UserDefaults.standard.data(forKey: key),
              let state = try? JSONDecoder().decode(SavedGameState.self, from: data)
        else { return false }

        manager.resetAlexPipelineForRestore()

        manager.denialScore       = state.denialScore
        manager.turnCount         = state.turnCount
        manager.currentScene      = state.currentScene
        manager.currentAct        = state.currentAct
        manager.currentPath       = state.currentPath
        manager.hasSentEndingFile = state.hasSentEndingFile
        manager.trustCount        = state.trustCount ?? 0
        manager.denialCount       = state.denialCount ?? 0
        manager.avoidanceCount    = state.avoidanceCount ?? 0

        // Restore visual triggers so GlitchScene immediately syncs on Continue
        manager.glitchTrigger = state.glitchTrigger ?? 0
        manager.shadowTrigger = state.shadowTrigger ?? 0
        manager.crackTrigger  = state.crackTrigger  ?? 0

        manager.messages = state.savedMessages.compactMap { saved in
            let type: MessageType
            switch saved.typeKey {
            case "systemAlert": type = .systemAlert
            case "image":       type = .image(saved.typePayload)
            case "voiceNote":   type = .voiceNote(saved.typePayload)
            case "lockedFile":  type = .lockedFile(saved.typePayload)
            default:            type = .text
            }
            // Missing `isRead` in older saves: player bubbles default read; Alex inbound defaults unread
            // so the lock-screen feed can show activity after returning.
            return Message(text: saved.text, isFromMe: saved.isFromMe,
                           time: saved.time, isRead: saved.isRead ?? saved.isFromMe, type: type)
        }

        if let savedChoices = state.currentChoices {
            manager.currentChoices = savedChoices.compactMap {
                guard let type = ChoiceType(rawValue: $0.typeString) else { return nil }
                return PlayerChoice(text: $0.text, type: type)
            }
        }

        if let lpc = state.lastPlayerChoice, let type = ChoiceType(rawValue: lpc.typeString) {
            manager.lastPlayerChoice = PlayerChoice(text: lpc.text, type: type)
        }

        manager.pastChoices = state.pastChoices ?? []

        // Lock all scene didEnter side-effects during state machine restore
        manager.isRestoringFromSave = true

        let t = state.turnCount
        if      t >= 9 { manager.stateMachine?.enter(SceneEndingState.self) }
        else if t >= 8 { manager.stateMachine?.enter(Scene8State.self) }
        else if t >= 7 { manager.stateMachine?.enter(Scene7State.self) }
        else if t >= 6 { manager.stateMachine?.enter(Scene6State.self) }
        else if t >= 5 { manager.stateMachine?.enter(Scene5State.self) }
        else if t >= 4 { manager.stateMachine?.enter(Scene4State.self) }
        else if t >= 2 { manager.stateMachine?.enter(Scene3State.self) }
        else if t >= 1 { manager.stateMachine?.enter(Scene2State.self) }
        else           { manager.stateMachine?.enter(Scene1State.self) }

        manager.isRestoringFromSave = false
        // Audit §10.3: rehydrate the LLM session with the saved conversation so Alex
        // resumes with full memory of prior turns, not a blank persona.
        manager.rebuildSessionFromHistory(manager.messages)

        // Re-activate heartbeat if the saved scene requires it
        let heartbeatScenes = ["S7", "S8"]
        if heartbeatScenes.contains(state.currentScene) {
            manager.startHeartbeat()
        }

        // Audit fix: Scene 5 advances via a fire-and-forget DispatchQueue inside its
        // didEnter. On restore, didEnter is skipped (isRestoringFromSave guard) so that
        // dispatched closure never re-fires — the player would be stuck in S5 forever.
        // Re-schedule it here, using the same delay constant.
        if state.currentScene == "S5", state.turnCount < 6 {
            manager.scheduleScene5BridgeAdvanceIfNeeded()
        }

        // Alex continuation after a mid-turn save is started from the home hub via `resumePendingAlexReplyIfNeeded()`
        // (avoid duplicate `generateAlexReply` tasks vs. the same call on first home appearance).

        return true
    }

    func clearSave() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    var savedDateString: String? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let state = try? JSONDecoder().decode(SavedGameState.self, from: data)
        else { return nil }

        let fmt = DateFormatter()
        fmt.dateStyle = .short
        fmt.timeStyle = .short
        return fmt.string(from: state.savedDate)
    }
}
