import Foundation

// MARK: - Model
// Audit follow-up (§6, §10.9): trimmed to the fields actually consumed by the runtime.
// The Files screen (`FilesEvidenceView`) derives its visible content from
// `gameManager.messages`, not from this manager — so `title`, `content`, `assetName`,
// and `FragmentType` were unused metadata. They were removed to keep the model
// lightweight. Codable still decodes older on-disk saves (extra JSON fields are
// ignored by Swift's default Codable behavior).

struct EvidenceFragment: Identifiable, Codable {
    let id: String
    var isUnlocked: Bool
    var unlockedInScene: String
}

/// Canonical catalogue of fragments. Each entry maps a scene ID to an unlock token
/// — the actual narrative content surfaces through chat messages in `FilesEvidenceView`.
struct EvidenceDatabase {
    static let all: [EvidenceFragment] = [
        EvidenceFragment(id: "F001", isUnlocked: false, unlockedInScene: "S1"),
        EvidenceFragment(id: "F002", isUnlocked: false, unlockedInScene: "S3"),
        EvidenceFragment(id: "F003", isUnlocked: false, unlockedInScene: "S4"),
        EvidenceFragment(id: "F004", isUnlocked: false, unlockedInScene: "S5"),
        EvidenceFragment(id: "F005", isUnlocked: false, unlockedInScene: "S6"),
        EvidenceFragment(id: "F006", isUnlocked: false, unlockedInScene: "S7"),
        EvidenceFragment(id: "F007", isUnlocked: false, unlockedInScene: "ENDING")
    ]
}
