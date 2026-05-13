//
//  Scene8State.swift
//  StoryGameRead214
//
//  Extracted from ContentView.swift — S8: System Break (Climax).
//

import GameplayKit

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
