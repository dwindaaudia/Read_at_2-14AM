//
//  Scene3State.swift
//  StoryGameRead214
//
//  Extracted from ContentView.swift — S3: Image Reveal.
//

import GameplayKit

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
        case .high, .extreme:levelText = "Alex is insistent. The glitch and haptic have disoriented the player. Messages arrive fast."
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
