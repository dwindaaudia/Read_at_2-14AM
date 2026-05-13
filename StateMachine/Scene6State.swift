//
//  Scene6State.swift
//  StoryGameRead214
//
//  Extracted from ContentView.swift — S6: Decrypt File (Act 2).
//

import GameplayKit

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
