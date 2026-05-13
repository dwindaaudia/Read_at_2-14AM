//
//  Scene1State.swift
//  StoryGameRead214
//
//  Extracted from ContentView.swift — S1: Initial contact, no AI.
//

import GameplayKit

// S1: Tanpa AI, hanya inisiasi
final class Scene1State: NarrativeState {
    override func didEnter(from previousState: GKState?) {
        super.didEnter(from: previousState)
        manager.currentAct = 1
        
        if manager.messages.isEmpty {
            manager.addAlexMessage("Are you awake?", type: .text)
            manager.setChoices(["Alex?! Is that you?", "Who is this? This isn't funny.", "Ignore"])
        }
    }
}
