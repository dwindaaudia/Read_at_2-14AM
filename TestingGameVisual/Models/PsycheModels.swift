import Foundation

// MARK: - Context Enums

enum PlayerEmotionState: String {
    case hostile = "HOSTILE"
    case neutral = "NEUTRAL"
    case trust   = "TRUST"
}

enum AlexToneState: String {
    case aggressive = "Aggressive"
    case uncertain  = "Uncertain"
    case calm       = "Melancholic"
}

/// Per-scene branching level derived from denialScore.
// TODO: PsycheLevel .extreme still exist
enum PsycheLevel {
    case low, medium, high, extreme
}
