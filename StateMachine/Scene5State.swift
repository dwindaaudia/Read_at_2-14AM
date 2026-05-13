//
//  Scene5State.swift
//  StoryGameRead214
//
//  Extracted from ContentView.swift — S5: Cliffhanger ending.
//

import GameplayKit

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
