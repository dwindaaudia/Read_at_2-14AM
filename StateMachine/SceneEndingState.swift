//
//  SceneEndingState.swift
//  StoryGameRead214
//
//  Extracted from ContentView.swift — Final resolution + restart.
//

import GameplayKit

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
