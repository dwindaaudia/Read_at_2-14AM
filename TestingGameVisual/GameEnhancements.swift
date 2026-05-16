// GameEnhancements.swift
// "Read at 2:14 AM" — Enhancement Pack

import SwiftUI
import AVFoundation
import Combine
import GameplayKit

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: 1. GAME SAVE SYSTEM
// MARK: ─────────────────────────────────────────────────────────────────────

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
        let isRead: Bool?
    }
    
    struct SavedChoice: Codable {
        let text: String
        let typeString: String
    }
}

final class GameSaveManager {
    static let shared = GameSaveManager()
    private let key = "ra214_savedGameState"
    
    var hasSave: Bool {
        UserDefaults.standard.data(forKey: key) != nil
    }
    
    func save(from manager: GameManager) {
        guard manager.currentScene != "ENDING",
              !manager.messages.isEmpty else { return }
        
        let savedMessages = manager.messages.map { msg -> SavedGameState.SavedMessage in
            var typeKey = "text"
            var typePayload = ""
            switch msg.type {
            case .text:               typeKey = "text"
            case .systemAlert:        typeKey = "systemAlert"
            case .image(let name):    typeKey = "image";      typePayload = name
            case .voiceNote(let id):  typeKey = "voiceNote";  typePayload = id
            case .lockedFile(let id): typeKey = "lockedFile"; typePayload = id
            }
            return SavedGameState.SavedMessage(
                text: msg.text, isFromMe: msg.isFromMe,
                time: msg.time, typeKey: typeKey, typePayload: typePayload,
                isRead: msg.isRead
            )
        }
        
        let currentChoices = manager.currentChoices.map {
            SavedGameState.SavedChoice(text: $0.text, typeString: $0.type.rawValue)
        }
        let lastPlayerChoice = manager.lastPlayerChoice.map {
            SavedGameState.SavedChoice(text: $0.text, typeString: $0.type.rawValue)
        }
        
        let state = SavedGameState(
            denialScore:       manager.denialScore,
            turnCount:         manager.turnCount,
            currentScene:      manager.currentScene,
            currentAct:        manager.currentAct,
            currentPath:       manager.currentPath,
            hasSentEndingFile: manager.hasSentEndingFile,
            savedMessages:     savedMessages,
            savedDate:         Date(),
            currentChoices:    currentChoices,
            lastPlayerChoice:  lastPlayerChoice,
            pastChoices:       manager.pastChoices,
            trustCount:        manager.trustCount,
            denialCount:       manager.denialCount,
            avoidanceCount:    manager.avoidanceCount,
            glitchTrigger:     manager.glitchTrigger,
            shadowTrigger:     manager.shadowTrigger,
            crackTrigger:      manager.crackTrigger
        )
        
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    @discardableResult
    func restore(into manager: GameManager) -> Bool {
        guard let data = UserDefaults.standard.data(forKey: key),
              let state = try? JSONDecoder().decode(SavedGameState.self, from: data)
        else { return false }
        
        manager.resetAlexPipelineForRestore()
        
        manager.denialScore       = state.denialScore
        manager.turnCount         = state.turnCount
        manager.currentScene      = state.currentScene
        manager.currentAct        = state.currentAct
        manager.currentPath       = state.currentPath
        manager.hasSentEndingFile = state.hasSentEndingFile
        manager.trustCount        = state.trustCount ?? 0
        manager.denialCount       = state.denialCount ?? 0
        manager.avoidanceCount    = state.avoidanceCount ?? 0
        
        // Restore visual triggers so GlitchScene immediately syncs on Continue
        manager.glitchTrigger = state.glitchTrigger ?? 0
        manager.shadowTrigger = state.shadowTrigger ?? 0
        manager.crackTrigger  = state.crackTrigger  ?? 0
        
        manager.messages = state.savedMessages.compactMap { saved in
            let type: MessageType
            switch saved.typeKey {
            case "systemAlert": type = .systemAlert
            case "image":       type = .image(saved.typePayload)
            case "voiceNote":   type = .voiceNote(saved.typePayload)
            case "lockedFile":  type = .lockedFile(saved.typePayload)
            default:            type = .text
            }
            // Missing `isRead` in older saves: player bubbles default read; Alex inbound defaults unread so the lock-screen feed can show activity after returning.
            return Message(text: saved.text, isFromMe: saved.isFromMe,
                           time: saved.time, isRead: saved.isRead ?? saved.isFromMe, type: type)
        }
        
        if let savedChoices = state.currentChoices {
            manager.currentChoices = savedChoices.compactMap {
                guard let type = ChoiceType(rawValue: $0.typeString) else { return nil }
                return PlayerChoice(text: $0.text, type: type)
            }
        }
        
        if let lpc = state.lastPlayerChoice, let type = ChoiceType(rawValue: lpc.typeString) {
            manager.lastPlayerChoice = PlayerChoice(text: lpc.text, type: type)
        }
        
        manager.pastChoices = state.pastChoices ?? []
        
        // Lock all scene didEnter side-effects during state machine restore
        manager.isRestoringFromSave = true
        
        let t = state.turnCount
        if      t >= 9 { manager.stateMachine?.enter(SceneEndingState.self) }
        else if t >= 8 { manager.stateMachine?.enter(Scene8State.self) }
        else if t >= 7 { manager.stateMachine?.enter(Scene7State.self) }
        else if t >= 6 { manager.stateMachine?.enter(Scene6State.self) }
        else if t >= 5 { manager.stateMachine?.enter(Scene5State.self) }
        else if t >= 4 { manager.stateMachine?.enter(Scene4State.self) }
        else if t >= 2 { manager.stateMachine?.enter(Scene3State.self) }
        else if t >= 1 { manager.stateMachine?.enter(Scene2State.self) }
        else           { manager.stateMachine?.enter(Scene1State.self) }
        
        manager.isRestoringFromSave = false
        manager.refreshAISession()
        
        // Re-activate heartbeat if the saved scene requires it
        let heartbeatScenes = ["S7", "S8"]
        if heartbeatScenes.contains(state.currentScene) {
            manager.startHeartbeat()
        }
        
        // Alex continuation after a mid-turn save is started from the home hub via `resumePendingAlexReplyIfNeeded()`
        // (avoid duplicate `generateAlexReply` tasks vs. the same call on first home appearance).
        
        return true
    }
    
    func clearSave() {
        UserDefaults.standard.removeObject(forKey: key)
    }
    
    var savedDateString: String? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let state = try? JSONDecoder().decode(SavedGameState.self, from: data)
        else { return nil }
        
        let fmt = DateFormatter()
        fmt.dateStyle = .short
        fmt.timeStyle = .short
        return fmt.string(from: state.savedDate)
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: 2. IMAGE LIGHTBOX
// MARK: ─────────────────────────────────────────────────────────────────────

struct ImageLightboxView: View {
    let assetName: String
    let caption: String
    /// Chat uses sharp corners; evidence log keeps default.
    var thumbnailCornerRadius: CGFloat = 12
    
    @State private var isExpanded = false
    @State private var scale: CGFloat = 1.0
    @Namespace private var ns
    private var captionBackground: Color {
        thumbnailCornerRadius <= 4 ? Color(white: 0.94) : Color(UIColor.secondarySystemBackground)
    }
    
    private var captionForeground: Color {
        thumbnailCornerRadius <= 4 ? Color.black.opacity(0.78) : Color.primary
    }
    
    var body: some View {
        ZStack {
            if !isExpanded {
                thumbnail
                    .matchedGeometryEffect(id: "img_\(assetName)", in: ns)
            }
            if isExpanded {
                fullscreenOverlay
            }
        }
    }
    
    private var thumbnail: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomTrailing) {
                Image(assetName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 240, height: 180)
                    .clipped()
                
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.caption)
                    .padding(6)
                    .background(Color.black.opacity(0.6), in: Circle())
                    .foregroundColor(.white)
                    .padding(8)
            }
            
            if !caption.isEmpty {
                Text(caption)
                    .font(.caption)
                    .foregroundColor(captionForeground)
                    .padding(10)
                    .frame(maxWidth: 240, alignment: .leading)
                    .background(captionBackground)
            }
        }
        .cornerRadius(thumbnailCornerRadius)
        .onTapGesture {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                isExpanded = true
            }
            HapticManager.shared.playTypeHaptic()
        }
    }
    
    private var fullscreenOverlay: some View {
        ZStack {
            Color.black.opacity(0.95)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        isExpanded = false
                        scale = 1.0
                    }
                }
            
            VStack(spacing: 16) {
                HStack {
                    Spacer()
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            isExpanded = false
                            scale = 1.0
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.white.opacity(0.15), in: Circle())
                    }
                    .padding()
                }
                
                Spacer()
                
                Image(assetName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .matchedGeometryEffect(id: "img_\(assetName)", in: ns)
                    .scaleEffect(scale)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { scale = $0 }
                            .onEnded { _ in
                                withAnimation { scale = max(1.0, min(scale, 4.0)) }
                            }
                    )
                    .padding()
                
                if !caption.isEmpty {
                    Text(caption)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal)
                }
                
                HStack(spacing: 16) {
                    Label("Oct 18, 2019", systemImage: "calendar")
                    Label("2:14 AM", systemImage: "clock")
                }
                .font(.caption.monospaced())
                .foregroundColor(.gray)
                .padding(.bottom, 40)
            }
        }
        .transition(.opacity)
        .zIndex(999)
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: 4. VOICE NOTE PLAYER
// MARK: ─────────────────────────────────────────────────────────────────────

final class VoiceNoteAudioController: ObservableObject {
    @Published var isPlaying = false
    @Published var progress: Double = 0.0
    @Published var duration: Double = 1.0
    
    private var player: AVAudioPlayer?
    private var timer: Timer?
    
    func toggle(filename: String) {
        if isPlaying { stop() } else { play(filename: filename) }
    }
    
    private func play(filename: String) {
        let name = filename.replacingOccurrences(of: ".mp3", with: "")
        guard let url = Bundle.main.url(forResource: name, withExtension: "mp3") else {
            simulateFallback()
            return
        }
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.volume = AppSettings.shared.sfxVolume
            player?.play()
            duration = player?.duration ?? 3.0
            isPlaying = true
            startTimer()
        } catch {
            simulateFallback()
        }
    }
    
    private func simulateFallback() {
        duration = 3.0
        isPlaying = true
        startTimer()
    }
    
    private func stop() {
        player?.stop()
        timer?.invalidate()
        isPlaying = false
        progress = 0
    }
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self else { return }
            DispatchQueue.main.async {
                // Keep volume in sync with user settings on every tick
                self.player?.volume = AppSettings.shared.sfxVolume
                self.progress = min(1.0, self.progress + (0.05 / self.duration))
                if self.progress >= 1.0 { self.stop() }
            }
        }
    }
    
    deinit {
        timer?.invalidate()
        player?.stop()
    }
}

struct VoiceNotePlayerBubble: View {
    let filename: String
    let isFromMe: Bool
    
    @StateObject private var controller = VoiceNoteAudioController()
    @State private var barHeights: [CGFloat] = (0..<28).map { _ in CGFloat.random(in: 6...22) }
    
    var body: some View {
        HStack(spacing: 10) {
            Button {
                controller.toggle(filename: filename)
                HapticManager.shared.playTypeHaptic()
            } label: {
                Image(systemName: controller.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(isFromMe ? .white : Color(red: 0.5, green: 0, blue: 0.02))
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 2.5) {
                    ForEach(barHeights.indices, id: \.self) { i in
                        let fraction = Double(i) / Double(barHeights.count)
                        let isPast = fraction <= controller.progress
                        Capsule()
                            .fill(waveColor(isPast: isPast))
                            .frame(width: 3, height: barHeights[i])
                            .scaleEffect(
                                controller.isPlaying && isPast ? 1.0 : 0.6,
                                anchor: .bottom
                            )
                            .animation(
                                controller.isPlaying
                                ? .easeInOut(duration: 0.15).delay(Double(i) * 0.01)
                                : .easeOut(duration: 0.2),
                                value: controller.isPlaying
                            )
                    }
                }
                .frame(height: 28)
                
                HStack {
                    Text(formattedTime(controller.duration * controller.progress))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(isFromMe ? .white.opacity(0.85) : .black.opacity(0.55))
                    Spacer()
                    Text(formattedTime(controller.duration))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(isFromMe ? .white.opacity(0.65) : .black.opacity(0.45))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(isFromMe ? Color(red: 0.545, green: 0, blue: 0) : Color.white)
        .clipShape(Rectangle())
        .frame(maxWidth: 260, alignment: isFromMe ? .trailing : .leading)
        .fixedSize(horizontal: true, vertical: false)
    }
    
    private func waveColor(isPast: Bool) -> Color {
        if isPast {
            return isFromMe ? .white.opacity(0.95) : Color(red: 0.55, green: 0.05, blue: 0.08)
        } else {
            return isFromMe ? .white.opacity(0.35) : Color.black.opacity(0.2)
        }
    }
    
    private func formattedTime(_ seconds: Double) -> String {
        let s = Int(seconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: 5. MESSAGE BUBBLE ENHANCED
// MARK: ─────────────────────────────────────────────────────────────────────

/// System / ERROR lines: uneven per-character delays (machine “stutter”) before the full line appears.
fileprivate struct HorrorSystemAlertReveal: View {
    let fullText: String
    
    @State private var visible = ""
    
    var body: some View {
        Text(displayString)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundColor(Color(red: 1, green: 0.45, blue: 0.45))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(Color.black.opacity(0.55))
            .overlay(Rectangle().stroke(Color.red.opacity(0.55), lineWidth: 1))
            .task(id: fullText) { await crawlOut() }
    }
    
    private var displayString: String {
        if visible == fullText { return fullText }
        return visible + "█"
    }
    
    @MainActor
    private func crawlOut() async {
        visible = ""
        for (idx, ch) in fullText.enumerated() {
            if Task.isCancelled { return }
            let base = UInt64.random(in: 28_000_000 ... 110_000_000)
            try? await Task.sleep(nanoseconds: base)
            if Task.isCancelled { return }
            visible.append(ch)
            if idx % 11 == 10 {
                HapticManager.shared.playTypeHaptic()
            }
            if Double.random(in: 0...1) < 0.22 {
                try? await Task.sleep(nanoseconds: UInt64.random(in: 70_000_000 ... 190_000_000))
            }
        }
        visible = fullText
    }
}

struct MessageBubbleEnhanced: View {
    let message: Message
    
    private static let youBubble = Color(red: 0.545, green: 0, blue: 0)
    private static let bubbleMax: CGFloat = 280
    
    var body: some View {
        Group {
            switch message.type {
            case .systemAlert:
                HorrorSystemAlertReveal(fullText: message.text)
            default:
                if message.isFromMe {
                    outgoingRow
                } else {
                    incomingRow
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
    
    @ViewBuilder
    private var incomingRow: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Alex")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                incomingBubbleContent
                    .layoutPriority(1)
                Text(message.time)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.white.opacity(0.42))
            }
            Spacer(minLength: 0)
        }
    }
    
    @ViewBuilder
    private var outgoingRow: some View {
        HStack(alignment: .top, spacing: 0) {
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 12) {
                Text("You")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .fixedSize(horizontal: true, vertical: true)
                HStack(alignment: .center, spacing: 4) {
                    readMetaOutgoing
                    outgoingBubbleContent
                }
                .animation(.spring(response: 0.42, dampingFraction: 0.86), value: message.isRead)
            }
            .fixedSize(horizontal: true, vertical: false)
        }
    }
    
    private var readMetaOutgoing: some View {
        VStack(alignment: .trailing, spacing: 3) {
            Text(message.isRead ? "Read" : "Delivered")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
                .contentTransition(.opacity)
                .multilineTextAlignment(.trailing)
            Text(message.time)
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(.white.opacity(0.65))
                .multilineTextAlignment(.trailing)
        }
        .fixedSize(horizontal: true, vertical: false)
    }
    
    @ViewBuilder
    private var incomingBubbleContent: some View {
        switch message.type {
        case .text:
            Text(message.text)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.black)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(Rectangle().fill(Color.white))
                .frame(maxWidth: Self.bubbleMax, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        case .image(let assetName):
            ImageLightboxView(assetName: assetName, caption: message.text, thumbnailCornerRadius: 0)
        case .voiceNote(let id):
            VoiceNotePlayerBubble(filename: id, isFromMe: false)
        case .lockedFile(let id):
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "lock.doc.fill")
                        .font(.title3)
                        .foregroundColor(Color(red: 0.55, green: 0, blue: 0.05))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Hidden file")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.black.opacity(0.85))
                        Text(id)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.black.opacity(0.55))
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: Self.bubbleMax, alignment: .leading)
            .background(Color.white)
            .overlay(Rectangle().stroke(Color.black.opacity(0.08), lineWidth: 1))
        default:
            EmptyView()
        }
    }
    
    @ViewBuilder
    private var outgoingBubbleContent: some View {
        switch message.type {
        case .text:
            Text(message.text)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(Rectangle().fill(Self.youBubble))
                .frame(maxWidth: Self.bubbleMax, alignment: .trailing)
                .fixedSize(horizontal: false, vertical: true)
        case .image(let assetName):
            ImageLightboxView(assetName: assetName, caption: message.text, thumbnailCornerRadius: 0)
                .fixedSize(horizontal: true, vertical: false)
        case .voiceNote(let id):
            VoiceNotePlayerBubble(filename: id, isFromMe: true)
        case .lockedFile(let id):
            VStack(alignment: .trailing, spacing: 8) {
                HStack(spacing: 10) {
                    Spacer(minLength: 0)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Hidden file")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                        Text(id)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white.opacity(0.75))
                    }
                    Image(systemName: "lock.doc.fill")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            .padding(14)
            .frame(maxWidth: Self.bubbleMax, alignment: .trailing)
            .background(Self.youBubble.opacity(0.95))
            .fixedSize(horizontal: true, vertical: false)
        default:
            EmptyView()
        }
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: 8. EVIDENCE BOARD SYSTEM
// ─────────────────────────────────────────────────────────────────────────────
// Unlocks hint fragments as scenes progress.
// Displayed as a cork board with red-string connections.
// Accessible via the paperclip icon in the chat header.

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

// MARK: - Manager

@MainActor
final class EvidenceBoardManager: ObservableObject {
    static let shared = EvidenceBoardManager()

    @Published var fragments: [EvidenceFragment] = EvidenceDatabase.all
    @Published var newFragmentID: String? = nil

    private let saveKey = "ra214_evidenceFragments"

    private init() { loadFromDisk() }

    /// Call from NarrativeState.didEnter() with the corresponding sceneID.
    func unlockFragment(forScene sceneID: String) {
        var changed = false
        for i in fragments.indices {
            if fragments[i].unlockedInScene == sceneID && !fragments[i].isUnlocked {
                fragments[i].isUnlocked = true
                newFragmentID = fragments[i].id
                changed = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                    if self.newFragmentID == self.fragments[i].id {
                        self.newFragmentID = nil
                    }
                }
            }
        }
        if changed { saveToDisk() }
    }

    func resetFragments() {
        fragments = EvidenceDatabase.all
        newFragmentID = nil
        saveToDisk()
    }

    var unlockedCount: Int { fragments.filter(\.isUnlocked).count }

    private func saveToDisk() {
        if let data = try? JSONEncoder().encode(fragments) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }

    private func loadFromDisk() {
        guard let data = UserDefaults.standard.data(forKey: saveKey),
              let saved = try? JSONDecoder().decode([EvidenceFragment].self, from: data) else { return }
        var merged = EvidenceDatabase.all
        for i in merged.indices {
            if let match = saved.first(where: { $0.id == merged[i].id }) {
                merged[i].isUnlocked = match.isUnlocked
            }
        }
        fragments = merged
    }
}

// MARK: - Evidence Board (toolbar entry → Files screen in NewFeatures.swift)

struct EvidenceBoardButton: View {
    @ObservedObject private var board = EvidenceBoardManager.shared
    @ObservedObject var gameManager: GameManager
    @State private var showBoard = false

    var body: some View {
        Button(action: { showBoard = true }) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                if board.newFragmentID != nil {
                    Circle().fill(Color.red).frame(width: 9, height: 9)
                        .offset(x: 3, y: -3)
                }
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showBoard) {
            FilesEvidenceView(gameManager: gameManager)
        }
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: 9. REAL-TIME 2:14 AM EVENT
// ─────────────────────────────────────────────────────────────────────────────
// Meta-horror: the game detects the real device clock.
// If the player opens the app at exactly 2:14 AM, Alex immediately knows —
// and sends a sequence of messages that will not appear at any other time.

struct RealTimeEventManager {
    static var isThe214Moment: Bool {
        let cal = Calendar.current
        let now = Date()
        return cal.component(.hour, from: now) == 2
            && cal.component(.minute, from: now) == 14
    }

    static let specialMessages: [(delay: Double, text: String)] = [
        (1.0,  "wait"),
        (3.0,  "it's 2:14"),
        (5.5,  "why are you awake right now"),
        (8.0,  "you opened this at the exact moment i disappeared"),
        (11.0, "that's not a coincidence"),
        (14.0, "you never forgot, did you"),
    ]
}

struct RealTimeEventModifier: ViewModifier {
    @ObservedObject var manager: GameManager
    @State private var hasChecked = false

    func body(content: Content) -> some View {
        content.onAppear {
            guard !hasChecked else { return }
            hasChecked = true
            guard RealTimeEventManager.isThe214Moment else { return }

            for item in RealTimeEventManager.specialMessages {
                DispatchQueue.main.asyncAfter(deadline: .now() + item.delay + 2.0) {
                    manager.addAlexMessage(item.text, type: .text)
                }
            }

            // Glitch burst at the end of the sequence
            let finalDelay = (RealTimeEventManager.specialMessages.last?.delay ?? 14) + 3.5
            DispatchQueue.main.asyncAfter(deadline: .now() + finalDelay) {
                manager.glitchTrigger += 4
                HapticManager.shared.playGlitchHaptic()
                AudioManager.shared.playSound("static_sfx")
            }
        }
    }
}

extension View {
    /// Attach to the main chat view: `.checkRealTimeEvent(manager: manager)`
    func checkRealTimeEvent(manager: GameManager) -> some View {
        modifier(RealTimeEventModifier(manager: manager))
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: 11. TYPING INDICATOR (Alex)
// ─────────────────────────────────────────────────────────────────────────────
// White bubble with three dots only — matches Alex text bubbles; hidden when `isTyping` is false.

struct AlexTypingIndicatorView: View {
    @State private var pulse = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.black.opacity(0.42))
                        .frame(width: 6, height: 6)
                        .scaleEffect(pulse ? 1.12 : 0.88)
                        .opacity(pulse ? 1.0 : 0.38)
                        .animation(
                            .easeInOut(duration: 0.45)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.16),
                            value: pulse
                        )
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 13)
            .background(
                Rectangle()
                    .fill(Color.white)
            )
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .onAppear { pulse = true }
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: 12. MEMORY BLEED OVERLAY
// ─────────────────────────────────────────────────────────────────────────────
// When denialScore ≥ 14, ghost echoes of Alex's previous messages
// occasionally appear translucent on screen, then fade away.
// Non-interactive — just a shadow of memory.

struct MemoryBleedOverlayView: View {
    let denialScore: Int
    let recentAlexMessages: [String]

    @State private var ghostText:    String  = ""
    @State private var ghostOpacity: Double  = 0
    @State private var ghostOffsetY: CGFloat = 0
    @State private var isScheduled:  Bool    = false

    var body: some View {
        ZStack {
            if ghostOpacity > 0 {
                Text(ghostText)
                    .font(.system(size: 17, weight: .ultraLight, design: .monospaced))
                    .foregroundColor(.white.opacity(ghostOpacity * 0.30))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 50)
                    .offset(y: ghostOffsetY)
                    .blur(radius: (1.0 - ghostOpacity) * 5)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .onAppear { scheduleIfNeeded() }
        .onChange(of: denialScore) { _, newVal in
            if newVal >= 14 { scheduleIfNeeded() }
        }
    }

    private func scheduleIfNeeded() {
        guard denialScore >= 14, !isScheduled else { return }
        isScheduled = true
        let delay = Double.random(in: 9...14)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { flash() }
    }

    private func flash() {
        guard denialScore >= 14 else { isScheduled = false; return }
        guard let msg = recentAlexMessages.randomElement() else { isScheduled = false; return }

        ghostText    = msg
        ghostOffsetY = CGFloat.random(in: -120...120)

        withAnimation(.easeIn(duration: 0.6))  { ghostOpacity = 1.0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeOut(duration: 1.4)) { ghostOpacity = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                isScheduled = false
                scheduleIfNeeded()
            }
        }
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: 13. TUTORIAL OVERLAY
// ─────────────────────────────────────────────────────────────────────────────
// Shown once on the player's first time in the chat room.

struct TutorialOverlayView: View {
    @Binding var isVisible: Bool
    @State private var pulse = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.88)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 28) {

                // Header
                VStack(spacing: 6) {
                    Text("INCOMING TRANSMISSION")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.gray)
                        .tracking(3)

                    Text("Your words\nshape his world.")
                        .font(.system(size: 26, weight: .black))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }

                // Choice color guide
                VStack(spacing: 14) {
                    TutorialChoiceRow(color: .blue,  label: "TRUST",
                                     description: "Believe Alex. Help him. Empathy over fear.")
                    TutorialChoiceRow(color: .red,   label: "REJECT",
                                     description: "Deny the truth. Fight back. Blame him.")
                    TutorialChoiceRow(color: .gray,  label: "AVOID",
                                     description: "Hesitate. Ignore. Pretend nothing is wrong.")
                }

                // Tap to dismiss cue
                Text("Tap anywhere to begin")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.gray.opacity(0.55))
                    .opacity(pulse ? 1.0 : 0.4)
                    .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: pulse)
                    .onAppear { pulse = true }
            }
            .padding(28)
            .background(Color.white.opacity(0.04))
            .cornerRadius(22)
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .padding(28)
            .onTapGesture { dismiss() }
        }
    }

    private func dismiss() {
        AppSettings.shared.hasSeenTutorial = true
        withAnimation(.easeOut(duration: 0.35)) { isVisible = false }
        HapticManager.shared.playTypeHaptic()
    }
}

private struct TutorialChoiceRow: View {
    let color: Color
    let label: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(color)
                .frame(width: 56)
                .padding(.vertical, 6)
                .background(color.opacity(0.18), in: Capsule())
                .overlay(Capsule().stroke(color.opacity(0.4), lineWidth: 1))
                .padding(.top, 1)

            Text(description)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.75))
                .lineSpacing(3)

            Spacer()
        }
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: 14. ACT TRANSITION OVERLAY
// MARK: ─────────────────────────────────────────────────────────────────────

struct ActTransitionView: View {
    let actNumber: Int
    let actTitle: String
    @Binding var isVisible: Bool

    @State private var blackOpacity: Double = 1.0
    @State private var textOpacity: Double  = 0.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
                .opacity(blackOpacity)

            VStack(spacing: 10) {
                Text("A C T  \(romanNumeral(actNumber))")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.gray)
                    .tracking(8)

                Text(actTitle)
                    .font(.system(size: 30, weight: .black))
                    .foregroundColor(.white)

                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 60, height: 1)
                    .padding(.top, 4)
            }
            .opacity(textOpacity)
        }
        .ignoresSafeArea()
        .onAppear { runTransitionAnimation() }
    }

    private func runTransitionAnimation() {
        withAnimation(.easeIn(duration: 0.35)) { blackOpacity = 1.0 }

        withAnimation(.easeIn(duration: 0.7).delay(0.4)) { textOpacity = 1.0 }
        HapticManager.shared.playTypeHaptic()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
            withAnimation(.easeOut(duration: 0.7)) {
                textOpacity  = 0
                blackOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                isVisible = false
            }
        }
    }

    private func romanNumeral(_ n: Int) -> String {
        switch n { case 1: "I"; case 2: "II"; case 3: "III"; default: "\(n)" }
    }
}
