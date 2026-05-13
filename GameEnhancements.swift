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
        
        UnknownContactManager.shared.saveState()
        
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
                time: msg.time, typeKey: typeKey, typePayload: typePayload
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
        
        UnknownContactManager.shared.restoreState()
        
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
            return Message(text: saved.text, isFromMe: saved.isFromMe,
                           time: saved.time, isRead: true, type: type)
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
        
        // Regenerate choices if the player had none when they quit
        if manager.currentChoices.isEmpty
            && manager.currentScene != "ENDING"
            && manager.currentScene != "S5" {
            Task { await manager.generateAlexReply() }
        }
        
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
// MARK: 2. TYPEWRITER TEXT
// MARK: ─────────────────────────────────────────────────────────────────────

struct TypewriterText: View {
    let fullText: String
    var speed: TimeInterval = 0.03
    
    @State private var displayed: String = ""
    @State private var task: Task<Void, Never>? = nil
    
    var body: some View {
        Text(displayed)
            .onAppear { startTyping() }
            .onDisappear { task?.cancel() }
    }
    
    private func startTyping() {
        displayed = ""
        task?.cancel()
        task = Task {
            for char in fullText {
                if Task.isCancelled { break }
                await MainActor.run { displayed.append(char) }
                try? await Task.sleep(nanoseconds: UInt64(speed * 1_000_000_000))
            }
        }
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: 3. IMAGE LIGHTBOX
// MARK: ─────────────────────────────────────────────────────────────────────

struct ImageLightboxView: View {
    let assetName: String
    let caption: String
    
    @State private var isExpanded = false
    @State private var scale: CGFloat = 1.0
    @Namespace private var ns
    
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
                    .padding(10)
                    .frame(maxWidth: 240, alignment: .leading)
                    .background(Color(UIColor.secondarySystemBackground))
            }
        }
        .cornerRadius(12)
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
                    .foregroundColor(isFromMe ? .white : .red)
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
                        .foregroundColor(isFromMe ? .white.opacity(0.7) : .gray)
                    Spacer()
                    Text(formattedTime(controller.duration))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(isFromMe ? .white.opacity(0.5) : .gray.opacity(0.6))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(isFromMe ? Color.red : Color(UIColor.secondarySystemBackground))
        .clipShape(ChatBubbleShape(isFromMe: isFromMe))
        .frame(maxWidth: 260)
    }
    
    private func waveColor(isPast: Bool) -> Color {
        if isPast {
            return isFromMe ? .white.opacity(0.9) : .red
        } else {
            return isFromMe ? .white.opacity(0.3) : Color.gray.opacity(0.35)
        }
    }
    
    private func formattedTime(_ seconds: Double) -> String {
        let s = Int(seconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: 5. EVIDENCE LOG / ARCHIVE
// MARK: ─────────────────────────────────────────────────────────────────────

struct EvidenceLogView: View {
    @ObservedObject var gameManager: GameManager
    @Environment(\.dismiss) var dismiss
    
    private var evidenceMessages: [Message] {
        gameManager.messages.filter {
            switch $0.type {
            case .image, .voiceNote, .lockedFile: return true
            default: return false
            }
        }
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("EVIDENCE LOG")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                        .tracking(4)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.gray)
                            .padding(12)
                            .background(Color.white.opacity(0.08), in: Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 16)
                
                if evidenceMessages.isEmpty {
                    Spacer()
                    Text("No evidence collected yet.")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.gray.opacity(0.5))
                    Spacer()
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(evidenceMessages) { msg in
                                EvidenceCard(message: msg)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 32)
                    }
                }
            }
        }
    }
}

private struct EvidenceCard: View {
    let message: Message
    
    var body: some View {
        Group {
            switch message.type {
            case .image(let name):
                ImageEvidenceCard(assetName: name, time: message.time)
            case .voiceNote(let filename):
                VoiceEvidenceCard(filename: filename, time: message.time)
            case .lockedFile(let id):
                LockedEvidenceCard(fileID: id, time: message.time)
            default:
                EmptyView()
            }
        }
    }
}

private struct ImageEvidenceCard: View {
    let assetName: String
    let time: String
    @State private var expanded = false
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image(assetName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 160)
                .clipped()
                .cornerRadius(10)
            
            LinearGradient(colors: [.clear, .black.opacity(0.7)],
                           startPoint: .center, endPoint: .bottom)
            .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 2) {
                Image(systemName: "photo.fill")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
                Text(time)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(8)
        }
        .onTapGesture { expanded = true }
        .fullScreenCover(isPresented: $expanded) {
            ImageLightboxView(assetName: assetName, caption: "")
        }
    }
}

private struct VoiceEvidenceCard: View {
    let filename: String
    let time: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "waveform")
                .font(.system(size: 28))
                .foregroundColor(.red.opacity(0.7))
            
            Text(filename.replacingOccurrences(of: ".mp3", with: ""))
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
                .lineLimit(1)
            
            Text(time)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.gray)
            
            VoiceNotePlayerBubble(filename: filename, isFromMe: false)
                .scaleEffect(0.82, anchor: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, -8)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.red.opacity(0.2), lineWidth: 1))
    }
}

private struct LockedEvidenceCard: View {
    let fileID: String
    let time: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "lock.doc.fill")
                .font(.system(size: 28))
                .foregroundColor(.red.opacity(0.7))
            
            Text(fileID)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
                .lineLimit(2)
            
            Text(time)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.gray)
            
            Text("ENCRYPTED")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.red)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color.red.opacity(0.12))
                .cornerRadius(4)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.red.opacity(0.2), lineWidth: 1))
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: 6. CINEMATIC ENDING VIEW
// MARK: ─────────────────────────────────────────────────────────────────────

struct CinematicEndingView: View {
    @ObservedObject var gameManager: GameManager
    let onPlayAgain: () -> Void
    let onReturnToMenu: () -> Void
    let onShare: (() -> Void)?
    
    @State private var phase: EndingPhase = .blackout
    @State private var showShareSheet = false
    @State private var shareImage: UIImage? = nil
    
    enum EndingPhase {
        case blackout, titleReveal, glitchIn, profileReveal, statsReveal, buttonsReveal
    }
    
    private var profile: (title: String, description: String, color: Color) {
        gameManager.psychologicalProfile
    }

    private var stats: (trust: Int, denial: Int, avoidance: Int) {
        (trust: gameManager.trustCount, denial: gameManager.denialCount, avoidance: gameManager.avoidanceCount)
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            scanlineBackground
            
            if phase == .titleReveal {
                Text("E N D I N G")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .tracking(10)
                    .transition(.opacity)
            }
            
            if phase != .blackout && phase != .titleReveal {
                VStack(spacing: 0) {
                    Spacer()
                    
                    if phase != .glitchIn {
                        VStack(spacing: 6) {
                            Text("SESSION TERMINATED")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundColor(.gray)
                                .tracking(4)
                            Text("OCT 18, 2019  ·  02:14 AM")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.gray.opacity(0.5))
                        }
                        .transition(.opacity)
                        .padding(.bottom, 24)
                    }
                    
                    if phase == .profileReveal || phase == .statsReveal || phase == .buttonsReveal {
                        profileCard
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.92)),
                                removal: .opacity
                            ))
                            .padding(.horizontal, 28)
                    }
                    
                    if phase == .statsReveal || phase == .buttonsReveal {
                        statsRow
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .padding(.top, 20)
                            .padding(.horizontal, 28)
                    }
                    
                    Spacer()
                    
                    if phase == .buttonsReveal {
                        buttonsSection
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .padding(.horizontal, 28)
                            .padding(.bottom, 50)
                    }
                }
            }
            
            if phase == .glitchIn {
                Color.white.opacity(0.08).ignoresSafeArea()
                    .transition(.opacity)
            }
        }
        .onAppear { runEndingAnimation() }
        .sheet(isPresented: $showShareSheet) {
            if let img = shareImage {
                ActivityViewRepresentable(items: [img])
            }
        }
    }
    
    private var scanlineBackground: some View {
        VStack(spacing: 0) {
            ForEach(0..<60, id: \.self) { i in
                Color.white.opacity(i % 3 == 0 ? 0.018 : 0).frame(height: 2)
                Color.clear.frame(height: 12)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
    
    private var profileCard: some View {
        VStack(spacing: 18) {
            profile.color.opacity(0.8).frame(height: 2).padding(.horizontal, -24)
            
            ZStack {
                Circle()
                    .fill(profile.color.opacity(0.12))
                    .frame(width: 64, height: 64)
                Image(systemName: profileIcon)
                    .font(.system(size: 28))
                    .foregroundColor(profile.color)
            }
            
            Text(profile.title)
                .font(.system(size: 34, weight: .black))
                .foregroundColor(profile.color)
                .multilineTextAlignment(.center)
            
            profile.color.opacity(0.3).frame(height: 1)
            
            Text(profile.description)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(profile.color.opacity(0.4), lineWidth: 1.5))
        )
        .shadow(color: profile.color.opacity(0.15), radius: 20)
    }
    
    private var profileIcon: String {
        switch profile.title {
        case "THE SAVIOR":   return "heart.fill"
        case "THE DENIER":   return "xmark.shield.fill"
        case "THE COWARD":   return "eye.slash.fill"
        default:             return "questionmark.circle.fill"
        }
    }
    
    private var statsRow: some View {
        HStack(spacing: 0) {
            EndingStatBlock(value: "\(stats.trust)",              label: "TRUST",  color: .blue)
            dividerLine
            EndingStatBlock(value: "\(stats.denial)",             label: "DENIAL", color: .red)
            dividerLine
            EndingStatBlock(value: "\(stats.avoidance)",          label: "AVOID",  color: .gray)
            dividerLine
            EndingStatBlock(value: "\(abs(gameManager.denialScore))", label: "PSYCH",  color: profile.color)
        }
        .background(Color.white.opacity(0.04))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
    
    private var dividerLine: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 1)
            .padding(.vertical, 12)
    }
    
    private var buttonsSection: some View {
        VStack(spacing: 12) {
            Button { generateShareAndPresent() } label: {
                Label("Share Ending", systemImage: "square.and.arrow.up")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(profile.color)
                    .cornerRadius(14)
            }
            
            Button {
                HapticManager.shared.playTypeHaptic()
                onPlayAgain()
            } label: {
                Text("Play Again")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.2), lineWidth: 1))
            }
            
            Button {
                HapticManager.shared.playTypeHaptic()
                onReturnToMenu()
            } label: {
                Text("Main Menu")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            .padding(.top, 4)
        }
    }
    
    private func runEndingAnimation() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeIn(duration: 1.5)) { phase = .titleReveal }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            withAnimation(.easeOut(duration: 0.8)) { phase = .blackout }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            withAnimation(.easeIn(duration: 0.3)) { phase = .glitchIn }
            HapticManager.shared.playGlitchHaptic()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.7) {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.75)) { phase = .profileReveal }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.9) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { phase = .statsReveal }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 7.7) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { phase = .buttonsReveal }

            // Unlock current ending and increment clear count
            let currentTitle = profile.title
            if !AppSettings.shared.unlockedEndings.contains(currentTitle) {
                AppSettings.shared.unlockedEndings.append(currentTitle)
            }
            AppSettings.shared.totalClears += 1
        }
    }
    
    private func generateShareAndPresent() {
        if #available(iOS 16.0, *) {
            shareImage = renderShareCard(profile: profile)
        }
        showShareSheet = true
    }
}

private struct EndingStatBlock: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .black, design: .monospaced))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundColor(.gray)
                .tracking(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: 7. MESSAGE BUBBLE ENHANCED
// MARK: ─────────────────────────────────────────────────────────────────────

struct MessageBubbleEnhanced: View {
    let message: Message
    var useTypewriter: Bool = false
    
    var body: some View {
        HStack {
            if message.isFromMe { Spacer() }
            
            VStack(alignment: message.isFromMe ? .trailing : .leading, spacing: 4) {
                switch message.type {
                    
                case .systemAlert:
                    Text(message.text)
                        .font(.caption.monospaced())
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .foregroundColor(.red).background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red, lineWidth: 1))
                    
                case .text:
                    if useTypewriter && !message.isFromMe {
                        TypewriterText(fullText: message.text, speed: 0.025)
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .foregroundColor(.primary)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(ChatBubbleShape(isFromMe: false))
                    } else {
                        Text(message.text)
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .foregroundColor(message.isFromMe ? .white : .primary)
                            .background(message.isFromMe ? Color.red.opacity(0.45) : Color(UIColor.secondarySystemBackground))
                            .clipShape(ChatBubbleShape(isFromMe: message.isFromMe))
                    }
                    
                case .image(let assetName):
                    ImageLightboxView(assetName: assetName, caption: message.text)
                    
                case .voiceNote(let id):
                    VoiceNotePlayerBubble(filename: id, isFromMe: message.isFromMe)
                    
                case .lockedFile(let id):
                    HStack(spacing: 12) {
                        Image(systemName: "lock.doc.fill").font(.title2).foregroundColor(.red)
                        VStack(alignment: .leading) {
                            Text("Hidden File").font(.subheadline).fontWeight(.bold)
                            Text(id).font(.caption).foregroundColor(.gray)
                        }
                    }
                    .padding(14)
                    .background(Color(white: 0.15)).foregroundColor(.white)
                    .clipShape(ChatBubbleShape(isFromMe: message.isFromMe))
                    .overlay(ChatBubbleShape(isFromMe: message.isFromMe).stroke(Color.red.opacity(0.5), lineWidth: 1))
                }
                
                if message.type != .systemAlert {
                    HStack(spacing: 4) {
                        Text(message.time)
                        if message.isFromMe {
                            Image(systemName: message.isRead ? "checkmark.message.fill" : "checkmark.message")
                                .foregroundColor(message.isRead ? .red.opacity(0.45) : .gray)
                        }
                    }
                    .font(.caption2).foregroundColor(.white.opacity(0.7))
                    .padding(message.isFromMe ? .trailing : .leading, 8)
                }
            }
            
            if !message.isFromMe { Spacer() }
        }
        .padding(.horizontal)
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

// MARK: - Evidence Board UI

struct EvidenceBoardView: View {
    @ObservedObject private var board = EvidenceBoardManager.shared
    @State private var selectedFragment: EvidenceFragment? = nil
    @Environment(\.dismiss) var dismiss

    // Fixed cork board positions per fragment index
    private let layout: [(x: CGFloat, y: CGFloat, rot: Double)] = [
        (-130, -200, -3.0), (110, -170,  2.5), (-100, -10, -1.5),
        ( 120,  20,   4.0), (-130, 160, -2.0), ( 100, 175,  3.5),
        (   0, -90,   1.0)
    ]

    var body: some View {
        ZStack {
            // Cork board texture
            Color(red: 0.13, green: 0.09, blue: 0.06).ignoresSafeArea()
            LinearGradient(
                colors: [.black.opacity(0.0), .black.opacity(0.5)],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Header ───────────────────────────────────────────────────
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white.opacity(0.6))
                            .padding(12)
                            .background(Color.white.opacity(0.08), in: Circle())
                    }
                    Spacer()
                    VStack(spacing: 3) {
                        Text("EVIDENCE BOARD")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .tracking(5).foregroundColor(.white.opacity(0.7))
                        Text("CASE: ALEX — 18 OCT 2019")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundColor(.red.opacity(0.7))
                    }
                    Spacer()
                    Text("\(board.unlockedCount)/\(board.fragments.count)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(12)
                }
                .padding(.horizontal)
                .padding(.top, 55)

                // ── Board Canvas ─────────────────────────────────────────────
                ScrollView([.horizontal, .vertical], showsIndicators: false) {
                    ZStack {
                        // Red string between unlocked fragments
                        EvidenceStringView(fragments: board.fragments, layout: layout)

                        // Fragment cards
                        ForEach(Array(board.fragments.enumerated()), id: \.element.id) { idx, fragment in
                            let pos = layout[idx % layout.count]
                            EvidenceCardView(fragment: fragment,
                                            isNew: board.newFragmentID == fragment.id)
                                .rotationEffect(.degrees(pos.rot))
                                .offset(x: pos.x, y: pos.y)
                                .onTapGesture {
                                    if fragment.isUnlocked {
                                        selectedFragment = fragment
                                        AudioManager.shared.playSound("page_flip")
                                    } else {
                                        HapticManager.shared.playGlitchHaptic()
                                        AudioManager.shared.playSound("static_sfx")
                                    }
                                }
                        }
                    }
                    .frame(width: 520, height: 740)
                    .padding(40)
                }
            }
        }
        .sheet(item: $selectedFragment) { fragment in
            FragmentDetailView(fragment: fragment)
        }
    }
}

struct EvidenceCardView: View {
    let fragment: EvidenceFragment
    let isNew: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 6) {
                Text(fragment.type.rawValue)
                    .font(.system(size: 7, weight: .black, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(fragment.isUnlocked ? typeColor : .gray.opacity(0.3))

                Text(fragment.isUnlocked ? fragment.title : "[ CLASSIFIED ]")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(fragment.isUnlocked ? .black : .gray.opacity(0.4))
                    .lineLimit(2)

                Text(fragment.isUnlocked
                     ? String(fragment.content.prefix(55)) + "…"
                     : "Lanjutkan cerita untuk\nmembuka fragmen ini.")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(fragment.isUnlocked ? .black.opacity(0.65) : .gray.opacity(0.25))
                    .lineLimit(3)
            }
            .padding(12)
            .frame(width: 145, height: 105)
            .background(
                fragment.isUnlocked
                    ? Color(red: 0.96, green: 0.93, blue: 0.83)
                    : Color(white: 0.12)
            )
            .clipShape(RoundedRectangle(cornerRadius: 2))
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(isNew ? Color.red.opacity(0.9) : Color.clear, lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.6), radius: 8, x: 3, y: 5)

            // Pin
            Circle()
                .fill(fragment.isUnlocked ? Color.red : Color.gray.opacity(0.4))
                .frame(width: 13, height: 13)
                .shadow(color: .black.opacity(0.4), radius: 2)
                .offset(x: -8, y: -4)
        }
        .overlay(alignment: .topLeading) {
            if isNew {
                Text("NEW")
                    .font(.system(size: 7, weight: .black))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(Color.red)
                    .offset(x: 4, y: -16)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: fragment.isUnlocked)
    }

    private var typeColor: Color {
        switch fragment.type {
        case .chatLog:   return .blue
        case .voiceNote: return .purple
        case .systemLog: return .red
        case .photo:     return .green
        case .callLog:   return .orange
        }
    }
}

struct EvidenceStringView: View {
    let fragments: [EvidenceFragment]
    let layout: [(x: CGFloat, y: CGFloat, rot: Double)]

    var body: some View {
        Canvas { ctx, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let unlocked = fragments.enumerated().filter { $0.element.isUnlocked }

            for i in 0..<(unlocked.count - 1) {
                let fromIdx = unlocked[i].offset % layout.count
                let toIdx   = unlocked[i + 1].offset % layout.count
                let from = CGPoint(x: center.x + layout[fromIdx].x,
                                   y: center.y + layout[fromIdx].y)
                let to   = CGPoint(x: center.x + layout[toIdx].x,
                                   y: center.y + layout[toIdx].y)

                var path = Path()
                path.move(to: from)
                path.addCurve(to: to,
                    control1: CGPoint(x: from.x + (to.x - from.x) * 0.3, y: from.y + 40),
                    control2: CGPoint(x: from.x + (to.x - from.x) * 0.7, y: to.y - 40))
                ctx.stroke(path, with: .color(.red.opacity(0.55)), lineWidth: 1)
            }
        }
        .frame(width: 520, height: 740)
        .allowsHitTesting(false)
    }
}

struct FragmentDetailView: View {
    let fragment: EvidenceFragment
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color(red: 0.95, green: 0.92, blue: 0.83).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.black.opacity(0.4)).padding(12)
                    }
                }
                .padding(.top, 50)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("— \(fragment.type.rawValue) —")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .tracking(3).foregroundColor(.gray)

                        Text(fragment.title)
                            .font(.system(size: 22, weight: .black, design: .monospaced))
                            .foregroundColor(.black)

                        Rectangle().fill(Color.black.opacity(0.15)).frame(height: 1)

                        if fragment.type == .photo, let asset = fragment.assetName {
                            Image(asset)
                                .resizable().scaledToFit()
                                .cornerRadius(8)
                                .padding(.vertical, 8)
                        } else if fragment.type == .voiceNote, let asset = fragment.assetName {
                            VoiceNotePlayerBubble(filename: asset, isFromMe: false)
                                .padding(.vertical, 8)
                        }

                        Text(fragment.content)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.black.opacity(0.8))
                            .lineSpacing(7)

                        Text("CASE FILE: ALEX — OCT 2019")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundColor(.red.opacity(0.4))
                            .padding(.top, 30)
                    }
                    .padding(32)
                }
            }
        }
    }
}

/// Accesses the Evidence Board. Place in the chat toolbar.
struct EvidenceBoardButton: View {
    @ObservedObject private var board = EvidenceBoardManager.shared
    @State private var showBoard = false

    var body: some View {
        Button(action: { showBoard = true }) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "paperclip")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                if board.newFragmentID != nil {
                    Circle().fill(Color.red).frame(width: 9, height: 9)
                        .offset(x: 3, y: -3)
                }
            }
        }
        .sheet(isPresented: $showBoard) { EvidenceBoardView() }
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: 9. UNKNOWN CONTACT SYSTEM
// ─────────────────────────────────────────────────────────────────────────────
// A second mystery contact (unknown number) that occasionally sends messages
// once denialScore ≥ 5. They know more than they should.
// Cannot be replied to. Cannot be called.

struct UnknownMessage: Identifiable, Codable {
    var id = UUID()
    let text: String
}

@MainActor
final class UnknownContactManager: ObservableObject {
    static let shared = UnknownContactManager()

    @Published var messages:   [UnknownMessage] = []
    @Published var hasUnread:  Bool = false
    @Published var showBanner: Bool = false
    @Published var bannerText: String = ""

    private let saveKey    = "ra214_unknownMsgs"
    private let indicesKey = "ra214_unknownIdx"

    // Messages with their minimum denialScore threshold
    private let pool: [(minDenial: Int, text: String)] = [
        (5,  "don't trust him"),
        (5,  "he's still at the bridge"),
        (5,  "you should have answered"),
        (8,  "2:14. that's when it happened"),
        (8,  "he called you first"),
        (8,  "i was there that night"),
        (10, "this is a loop. you've done this before"),
        (10, "he didn't fall. he waited"),
        (12, "you're the reason he's stuck"),
        (12, "stop denying. you know what happened"),
        (15, "he can't leave until YOU remember"),
        (15, "you missed his call. then you missed him"),
        (18, "this is the 4,392nd time you've read this"),
        (18, "YOU ARE NOW IN THE QUEUE"),
    ]
    private var usedIndices: Set<Int> = []

    private init() { restoreState() }

    func saveState() {
        if let d1 = try? JSONEncoder().encode(messages) {
            UserDefaults.standard.set(d1, forKey: saveKey)
        }
        if let d2 = try? JSONEncoder().encode(usedIndices) {
            UserDefaults.standard.set(d2, forKey: indicesKey)
        }
    }

    func restoreState() {
        if let d1 = UserDefaults.standard.data(forKey: saveKey),
           let s1 = try? JSONDecoder().decode([UnknownMessage].self, from: d1) {
            messages = s1
        }
        if let d2 = UserDefaults.standard.data(forKey: indicesKey),
           let s2 = try? JSONDecoder().decode(Set<Int>.self, from: d2) {
            usedIndices = s2
        }
    }

    func checkAndSchedule(denialScore: Int) {
        guard denialScore >= 5 else { return }
        let delay = Double.random(in: 20...60)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.fire(denialScore: denialScore)
        }
    }

    private func fire(denialScore: Int) {
        let eligible = pool.enumerated().filter {
            $0.element.minDenial <= denialScore && !usedIndices.contains($0.offset)
        }
        guard let pick = eligible.randomElement() else { return }
        usedIndices.insert(pick.offset)

        let text = pick.element.text

        bannerText = text
        withAnimation(.spring(response: 0.4)) { showBanner = true }
        AudioManager.shared.playSound("notification_sfx")
        HapticManager.shared.playGlitchHaptic()

        DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
            withAnimation { self.showBanner = false }
            self.messages.append(UnknownMessage(text: text))
            self.hasUnread = true
            self.saveState()
        }
    }

    func markRead() { hasUnread = false }

    func reset() {
        messages = []; hasUnread = false
        usedIndices = []; showBanner = false
    }
}

// Banner shown at the top of the screen when a message arrives
struct UnknownContactBannerView: View {
    @ObservedObject private var manager = UnknownContactManager.shared

    var body: some View {
        if manager.showBanner {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color.red.opacity(0.15)).frame(width: 42, height: 42)
                    Text("?")
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundColor(.red)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("+62 000-0214")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Text(manager.bannerText)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(1)
                }
                Spacer()
                Text("2:14 AM")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(14)
            .background(.ultraThinMaterial)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.red.opacity(0.35), lineWidth: 1))
            .cornerRadius(16)
            .shadow(color: .red.opacity(0.25), radius: 14)
            .padding(.horizontal, 16)
            .padding(.top, 58)
            .transition(.move(edge: .top).combined(with: .opacity))
            .allowsHitTesting(false)
        }
    }
}

// Full message thread for the unknown contact
struct UnknownContactView: View {
    @ObservedObject private var manager = UnknownContactManager.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                ZStack {
                    Color(white: 0.06).ignoresSafeArea(edges: .top)
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.left").foregroundColor(.white)
                        }
                        Spacer()
                        VStack(spacing: 2) {
                            Text("+62 000-0214")
                                .font(.headline).foregroundColor(.white)
                            Text("Tidak Dikenal")
                                .font(.caption).foregroundColor(.red)
                        }
                        Spacer()
                        Image(systemName: "info.circle").foregroundColor(.white.opacity(0.2))
                    }
                    .padding(.horizontal)
                    .padding(.top, 55).padding(.bottom, 12)
                }
                .frame(height: 100)

                if manager.messages.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "questionmark.bubble")
                            .font(.system(size: 40)).foregroundColor(.gray.opacity(0.3))
                        Text("Belum ada pesan.\nTerus bicara dengan Alex.")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(manager.messages) { msg in
                                HStack {
                                    Text(msg.text)
                                        .font(.system(size: 15, design: .monospaced))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 14).padding(.vertical, 10)
                                        .background(Color(white: 0.12))
                                        .clipShape(RoundedRectangle(cornerRadius: 18))
                                    Spacer()
                                }
                                .padding(.horizontal)
                            }

                            Text("[ KONTAK INI TIDAK BISA MENERIMA PESAN ]")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.red.opacity(0.4))
                                .padding(.top, 24)
                                .padding(.bottom, 40)
                        }
                        .padding(.top, 12)
                    }
                }
            }
        }
        .onAppear { manager.markRead() }
    }
}

/// Accesses the Unknown Contact thread. Place in the chat header.
struct UnknownContactButton: View {
    @ObservedObject private var manager = UnknownContactManager.shared
    @State private var showContact = false

    var body: some View {
        Button(action: { showContact = true }) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "questionmark.bubble.fill")
                    .font(.system(size: 18)).foregroundColor(.red.opacity(0.7))
                if manager.hasUnread {
                    Circle().fill(Color.red).frame(width: 9, height: 9).offset(x: 3, y: -3)
                }
            }
        }
        .sheet(isPresented: $showContact) { UnknownContactView() }
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: 10. REAL-TIME 2:14 AM EVENT
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
// MARK: 11. DYNAMIC TYPING INDICATOR
// ─────────────────────────────────────────────────────────────────────────────
// Alex's typing bubble changes based on psyche/denial level:
// — Low denial   : slow, melancholic, single dot
// — Medium       : normal, occasional brief pauses
// — High         : fast, label text starts to glitch
// — Extreme      : very fast, red, corrupted Ẕ̵a̵l̵g̵o̸ text

struct AlexTypingIndicatorView: View {
    let psycheLevel: PsycheLevel
    let denialScore: Int

    @State private var dotPhase: [Double] = [0, 0, 0]
    @State private var labelText: String  = "Alex is typing..."
    @State private var labelOffset: CGFloat = 0
    @State private var timer: Timer? = nil

    private var speed: Double {
        switch psycheLevel {
        case .low:     return 0.90
        case .medium:  return 0.55
        case .high:    return 0.28
        case .extreme: return 0.12
        }
    }

    private var dotColor: Color {
        switch psycheLevel {
        case .low, .medium: return .white.opacity(0.6)
        case .high:         return .red.opacity(0.85)
        case .extreme:      return .red
        }
    }

    private let labelsByLevel: [PsycheLevel: [String]] = [
        .low:     ["Alex is typing...", "typing...",   "..."],
        .medium:  ["Alex is typing...", "Alex is thinking...", "Still there..."],
        .high:    ["s o m e o n e  i s  t y p i n g", "process...", "please wait..."],
        .extreme: ["Ȃ̸l̷e̵x̶ is near", "SIGNAL CORRUPTED", "D̸̨̬̥͝O̷̧̱̐̾N̸̨̩͝'̶͙̂T̷̨̙̞̉̒ LOOK UP"],
    ]

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            // Dot group
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(dotColor)
                        .frame(width: 7, height: 7)
                        .scaleEffect(1.0 + dotPhase[i] * 0.4)
                        .offset(y: -dotPhase[i] * 4)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18))

            // Dynamic label
            Text(labelText)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
                .offset(x: psycheLevel == .extreme ? labelOffset : 0)
        }
        .padding(.horizontal)
        .onAppear { startAnimations() }
        .onDisappear { timer?.invalidate() }
    }

    private func startAnimations() {
        // Dot bounce animation
        withAnimation(.easeInOut(duration: speed).repeatForever(autoreverses: true)) {
            dotPhase[0] = 1
        }
        withAnimation(.easeInOut(duration: speed).repeatForever(autoreverses: true).delay(speed * 0.33)) {
            dotPhase[1] = 1
        }
        withAnimation(.easeInOut(duration: speed).repeatForever(autoreverses: true).delay(speed * 0.66)) {
            dotPhase[2] = 1
        }

        // Rotate label text on a timer
        let options = labelsByLevel[psycheLevel] ?? ["Alex is typing..."]
        timer = Timer.scheduledTimer(withTimeInterval: speed * 4.5, repeats: true) { _ in
            labelText = options.randomElement() ?? "..."
        }

        // Jittering x-offset for extreme level
        if psycheLevel == .extreme {
            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                labelOffset = CGFloat.random(in: -4...4)
            }
        }
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

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: 15. SIGNAL BAR VIEW
// ─────────────────────────────────────────────────────────────────────────────
// Shown in the toolbar. Represents the denial level as a decaying signal.

struct SignalBarView: View {
    let denialScore: Int

    @State private var glitchAlpha: Double = 1.0

    private var activeBars: Int {
        if denialScore >= 16 { return 1 }
        if denialScore >= 10 { return 2 }
        if denialScore >=  5 { return 3 }
        return 4
    }

    private var barColor: Color {
        if denialScore >= 12 { return .red    }
        if denialScore >=  7 { return .orange }
        if denialScore <= -7 { return .blue   }
        return .green
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 2.5) {
            ForEach(0..<4) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(i < activeBars ? barColor : Color.gray.opacity(0.25))
                    .frame(width: 4, height: CGFloat(5 + i * 5))
                    .opacity(i < activeBars && denialScore >= 16 ? glitchAlpha : 1.0)
            }
        }
        .padding(.trailing, 2)
        .onAppear { startGlitchIfNeeded() }
        .onChange(of: denialScore) { _, _ in startGlitchIfNeeded() }
    }

    private func startGlitchIfNeeded() {
        if denialScore >= 16 {
            withAnimation(.easeInOut(duration: 0.25).repeatForever(autoreverses: true)) {
                glitchAlpha = 0.25
            }
        } else {
            withAnimation(.easeOut(duration: 0.2)) { glitchAlpha = 1.0 }
        }
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: 16. ENDING SHARE CARD
// MARK: ─────────────────────────────────────────────────────────────────────

/// Rendered off-screen to produce a share image via ImageRenderer.
struct EndingShareCardView: View {
    let profile: (title: String, description: String, color: Color)

    var body: some View {
        ZStack {
            Color.black

            VStack(spacing: 0) {

                // Top accent line
                profile.color.opacity(0.7)
                    .frame(height: 3)

                VStack(spacing: 22) {

                    // Game title
                    VStack(spacing: 4) {
                        Text("READ AT 2:14 AM")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(.gray)
                            .tracking(4)
                        Text("A Psychological Horror Experience")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.gray.opacity(0.5))
                    }
                    .padding(.top, 28)

                    // Ending title
                    Text(profile.title)
                        .font(.system(size: 38, weight: .black))
                        .foregroundColor(profile.color)
                        .multilineTextAlignment(.center)

                    // Divider
                    profile.color.opacity(0.35).frame(height: 1).padding(.horizontal, 40)

                    // Description
                    Text(profile.description)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 24)

                    // Timestamp
                    Text("OCT 18, 2019  ·  02:14 AM")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.gray.opacity(0.5))
                        .padding(.bottom, 28)
                }

                // Bottom accent line
                profile.color.opacity(0.35).frame(height: 1)
            }
        }
        .frame(width: 320, height: 370)
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(profile.color.opacity(0.2), lineWidth: 1)
        )
    }
}

/// Renders the share card to a UIImage for sharing.
@available(iOS 16.0, *)
func renderShareCard(profile: (title: String, description: String, color: Color)) -> UIImage? {
    let renderer = ImageRenderer(content: EndingShareCardView(profile: profile))
    renderer.scale = 3.0
    return renderer.uiImage
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: 17. UIActivityViewController BRIDGE
// MARK: ─────────────────────────────────────────────────────────────────────

struct ActivityViewRepresentable: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: 18. FAKE STATUS BAR
// MARK: ─────────────────────────────────────────────────────────────────────

struct FakeStatusBarView: View {
    let time: String
    let batteryLevel: Double
    let denialScore: Int

    var body: some View {
        HStack {
            Text(time)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)

            Spacer()

            HStack(spacing: 4) {
                Text("\(Int(batteryLevel))%")
                    .font(.system(size: 12, design: .monospaced))

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color.white.opacity(0.4), lineWidth: 1)
                        .frame(width: 20, height: 10)

                    RoundedRectangle(cornerRadius: 1)
                        .fill(batteryLevel < 20 ? Color.red : Color.white)
                        .frame(width: CGFloat(batteryLevel / 100 * 18), height: 8)
                        .padding(.leading, 1)
                }
            }
            .foregroundColor(batteryLevel < 20 ? .red : .white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.5))
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: 19. CONTENT WARNING
// MARK: ─────────────────────────────────────────────────────────────────────

struct ContentWarningView: View {

    let onContinue: () -> Void

    @State private var contentOpacity: Double = 0
    @State private var iconPulse: Bool = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Warning icon
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.red.opacity(0.8))
                    .scaleEffect(iconPulse ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: iconPulse)
                    .onAppear { iconPulse = true }
                    .padding(.bottom, 24)

                Text("CONTENT WARNING")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.red.opacity(0.9))
                    .tracking(3)
                    .padding(.bottom, 20)

                // Warning items
                VStack(alignment: .leading, spacing: 10) {
                    WarningItem(text: "Psychological horror and sustained dread")
                    WarningItem(text: "Themes of loss, grief, and guilt")
                    WarningItem(text: "Disturbing imagery and audio")
                    WarningItem(text: "Flashing lights and visual distortion")
                }
                .padding(.bottom, 32)

                // Atmosphere recommendation
                Text("For maximum immersion:\nPlay alone · at night · with headphones.")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.bottom, 48)

                // CTA button
                Button {
                    HapticManager.shared.playTypeHaptic()
                    withAnimation(.easeIn(duration: 0.4)) { contentOpacity = 0 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { onContinue() }
                } label: {
                    Text("I UNDERSTAND — ENTER")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.red.opacity(0.18))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.red.opacity(0.4), lineWidth: 1)
                        )
                        .cornerRadius(12)
                }
                .padding(.horizontal, 40)

                Spacer()
            }
            .padding(.horizontal, 30)
        }
        .opacity(contentOpacity)
        .onAppear {
            withAnimation(.easeIn(duration: 0.7)) { contentOpacity = 1.0 }
        }
    }
}

private struct WarningItem: View {
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("·").foregroundColor(.red.opacity(0.7))
            Text(text).font(.subheadline).foregroundColor(.white.opacity(0.75))
        }
    }
}
