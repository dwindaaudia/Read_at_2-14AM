import Foundation

// MARK: - Message Data Models

//Message Model contain type
// TODO: - Seperating voiceNote, image, lockedFile as Asset and find whether this opt is plausible
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
    let isRead: Bool
    let type: MessageType
}
