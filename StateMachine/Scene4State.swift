//
//  Scene4State.swift
//  StoryGameRead214
//
//  Extracted from ContentView.swift — S4: Guilt Build & Voice Reveal.
//

import GameplayKit

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
        case .high, .extreme:asset = "VN_H1_INTENSE.mp3"
        }
        manager.triggerSpecialEvent(type: .voiceNote(asset), text: "Listen to me...")
    }
    
    override func getPromptData() -> (goal: String, situation: String) {
        let goal = "React to the scrolling chat logs and the voice note you just sent. This is the final communication before you disappear again. Make it sound like time is running out. Generate exactly 1 short Alex message."
        
        var audioDetail = ""
        switch manager.currentPsycheLevel {
        case .low:           audioDetail = "Calm voice note. Soft rain, slow breathing."
        case .medium:        audioDetail = "Unstable voice. Fast breathing, 'are you there?'."
        case .high, .extreme:audioDetail = "Chaotic voice. Footsteps, horn, fall, distortion."
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
