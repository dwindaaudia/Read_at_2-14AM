import Foundation

struct SavedGameState: Codable {
    var denialScore: Int
    var turnCount: Int
    var currentScene: String
    var currentAct: Int
    var currentPath: String
    var hasSentEndingFile: Bool
    var savedMessages: [SavedMessage]
    var savedDate: Date
    var currentChoices: [SavedChoice]?
    var lastPlayerChoice: SavedChoice?
    var pastChoices: [String]?
    
    var trustCount: Int?
    var denialCount: Int?
    var avoidanceCount: Int?
    
    // Visual effect triggers — restored on Continue to keep GlitchScene in sync
    var glitchTrigger: Int?
    var shadowTrigger: Int?
    var crackTrigger: Int?
    
    struct SavedMessage: Codable {
        let text: String
        let isFromMe: Bool
        let time: String
        let typeKey: String
        let typePayload: String
    }
    
    struct SavedChoice: Codable {
        let text: String
        let typeString: String
    }
}
