import Foundation

// MARK: - Model

struct EvidenceFragment: Identifiable, Codable {
    let id: String
    var title: String
    var content: String
    var assetName: String?
    var type: FragmentType
    var isUnlocked: Bool
    var unlockedInScene: String

    enum FragmentType: String, Codable {
        case chatLog   = "CHAT LOG"
        case voiceNote = "VOICE NOTE"
        case systemLog = "SYSTEM LOG"
        case photo     = "PHOTOGRAPH"
        case callLog   = "CALL LOG"
    }
}

// All fragments in the game
struct EvidenceDatabase {
    static let all: [EvidenceFragment] = [
        EvidenceFragment(
            id: "F001", title: "FIRST CONTACT",
            content: "Timestamp: 18 Oct 2019, 02:14 AM\nSender: Alex\n\n\"are you awake?\"\n\"i need to tell you something.\"\n\n[MESSAGE DELIVERED — NEVER READ]",
            assetName: nil, type: .chatLog, isUnlocked: false, unlockedInScene: "S1"
        ),
        EvidenceFragment(
            id: "F002", title: "YOU AND ALEX",
            content: "Location metadata: [CORRUPTED]\nTime: 02:11 AM, 18 Oct 2019\n\nTwo silhouettes. Heavy fog. The railing is barely visible. One figure is turning away.\n\n[LAST KNOWN PHOTOGRAPH]",
            assetName: "alex n friend", type: .photo, isUnlocked: false, unlockedInScene: "S3"
        ),
        EvidenceFragment(
            id: "F003", title: "VOICE LOG 01",
            content: "\"i know you're not picking up. it's okay.\"\n\"the rain got heavier. i can barely see.\"\n\"i just... i thought you'd be here.\"\n\"[unintelligible] ...don't worry about me.\"\n\n[AUDIO: 0:47 — STATIC AT END]",
            assetName: "VN_M1.mp3", type: .voiceNote, isUnlocked: false, unlockedInScene: "S4"
        ),
        EvidenceFragment(
            id: "F004", title: "CALL_LOG_2019",
            content: "18 Oct 2019\n02:13 AM — Alex → [YOU]\nDuration: 0 seconds\nStatus: UNANSWERED\n\nHe called exactly one minute before the connection dropped forever.",
            assetName: nil, type: .callLog, isUnlocked: false, unlockedInScene: "S5"
        ),
        EvidenceFragment(
            id: "F005", title: "SYS_ANOMALY",
            content: "ERROR: Message queue corrupted.\nSender: ALEX_CONTACT_7711\nQueue age: 1,826 days\nDelivery attempts: 4,392\n\nThese messages have been trying to reach you for five years.",
            assetName: nil, type: .systemLog, isUnlocked: false, unlockedInScene: "S6"
        ),
        EvidenceFragment(
            id: "F006", title: "UNSENT DRAFT",
            content: "Draft — Never Sent\nTimestamp: 18 Oct 2019, 02:13 AM\n\n\"i know you're scared. so am i.\"\n\"but i need you to—\"\n\n[MESSAGE UNSENT]\n[DEVICE OFFLINE: 02:14:32 AM]",
            assetName: nil, type: .chatLog, isUnlocked: false, unlockedInScene: "S7"
        ),
        EvidenceFragment(
            id: "F007", title: "FILE_01.enc",
            content: "HEARTBEAT MONITOR — DECRYPTED\n\n02:12 AM — Normal (72 BPM)\n02:14 AM — Elevated (130 BPM)\n02:14:32 AM — [SIGNAL LOST]\n\nYOU CALLED BACK.\nTHIRTY SECONDS TOO LATE.",
            assetName: nil, type: .systemLog, isUnlocked: false, unlockedInScene: "ENDING"
        )
    ]
}
