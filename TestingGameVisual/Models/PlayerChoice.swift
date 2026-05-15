import Foundation

/// rawValue is used as the `currentPath` string identifier.
enum ChoiceType: String {
    case trust      = "trust"
    case denial     = "denial"
    case avoidance  = "avoidance"
}

struct PlayerChoice: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let type: ChoiceType
}

struct FallbackResponse {
    var replies: [String]
    var choices: [String]
}
