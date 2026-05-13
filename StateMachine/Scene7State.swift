//
//  Scene7State.swift
//  StoryGameRead214
//
//  Extracted from ContentView.swift — S7: Memory Bleed.
//

import GameplayKit

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
