import Foundation

// MARK: - Message Data Models

enum MessageType: Equatable {
    case text
    case systemAlert
    case image(String)
    case voiceNote(String)
    case lockedFile(String)
}

struct Message: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let isFromMe: Bool
    let time: String
    /// For Alex-side messages: whether the player has already seen this in the chat thread.
    var isRead: Bool
    let type: MessageType
}
