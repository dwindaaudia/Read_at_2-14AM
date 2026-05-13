//
//  NarrativeState.swift
//  StoryGameRead214
//
//  Extracted from ContentView.swift — base GKState subclass for narrative scenes.
//

import GameplayKit

class NarrativeState: GKState {
    unowned let manager: ChatViewModel
    let sceneID: String
    let usesLLM: Bool
    let goal: String
    
    init(_ manager: ChatViewModel, sceneID: String, goal: String, usesLLM: Bool = true) {
        self.manager = manager
        self.sceneID = sceneID
        self.goal = goal
        self.usesLLM = usesLLM
        super.init()
    }
    
    override func didEnter(from previousState: GKState?) {
        manager.currentScene = sceneID
    }
    
    override func isValidNextState(_ stateClass: AnyClass) -> Bool { true }
    
    // Override per scene untuk inject narasi yang kaya ke prompt
    func getPromptData() -> (goal: String, situation: String) {
        return (goal: "Continue the conversation as Alex.", situation: "You are Alex.")
    }
}
