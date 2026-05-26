import Foundation
// Foundation Model for generating replies and choice
#if canImport(FoundationModels)
import FoundationModels

@available(iOS 18.0, macOS 15.0, *)
@Generable
struct AlexResponse {
    @Guide(description: """
    1-2 chat bubbles from ALEX only (not the player).
    Alex speaks TO the player using "you". English only.
    Voice: intimate, lowercase, fragmented, eerily calm; max ~15 words per bubble.
    Acknowledge the player's last message first, then advance the scene goal.
    Never repeat lines from recent chat history.
    """)
    var replies: [String]
    
    @Guide(description: """
    Exactly 3 lines the PLAYER would type back to Alex — not Alex speaking.
    English only. First person (I, me, my). Normal capitalization OK; full sentences.
    No labels ('Choice 1:', 'Trust:', etc.). Direct reactions to replies[].
    Order: [0] trust/helpful, [1] denial/hostile, [2] avoidance/hesitant.
    WRONG (Alex voice): "i'm still on the bridge. it's cold."
    RIGHT (player voice): "Where are you right now?"
    """)
    var choices: [String]
}

// Tagging for player emotions and topics because we use .contentTagging model
@available(iOS 18.0, macOS 15.0, *)
@Generable
struct PlayerChoiceTags {
    @Guide(
        description: "Most important emotion tags in the player's latest reply choice.",
        .maximumCount(2)
    )
    var emotions: [String]
    
    @Guide(
        description: "Most important topic tags in the player's latest reply choice.",
        .maximumCount(2)
    )
    var topics: [String]
}
#endif
