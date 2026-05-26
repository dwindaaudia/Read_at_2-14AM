import Foundation

// MARK: - Story file items (from Alex messages only)

enum AlexStoryFileKind {
    case photo
    case voice
    case archive
}

struct AlexStoryFileItem: Identifiable {
    let id: UUID
    let message: Message
    let displayName: String
    let kind: AlexStoryFileKind
}
