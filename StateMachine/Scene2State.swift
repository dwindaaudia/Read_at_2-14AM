//
//  Scene2State.swift
//  StoryGameRead214
//
//  Extracted from ContentView.swift — S2: First Contact.
//

import GameplayKit

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
        case .high, .extreme:levelText = "Alex is more fragmented. Messages arrive faster. He starts to repeat himself slightly."
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
