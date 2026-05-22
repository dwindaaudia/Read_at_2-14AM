import SwiftUI

// MARK: - TUTORIAL VIEW
// Shown once at first launch, before the main game begins.
// Teaches the player: (1) turn sound on, (2) choices shape the story.
// Integrates with AppSettings to mark tutorial as seen.

struct TutorialView: View {
    let onComplete: () -> Void

    // MARK: - Tutorial Node Model

    private struct TutorialNode {
        let id: Int
        let speaker: Speaker
        let text: String
        let choices: [TutorialChoice]
    }

    private struct TutorialChoice {
        let label: String
        let nextNode: Int
    }

    private enum Speaker {
        case alex, system
    }

    // MARK: - Script

    private let nodes: [Int: TutorialNode] = {
        var n = [Int: TutorialNode]()

        // NODE 1
        n[1] = TutorialNode(id: 1, speaker: .alex,
            text: "hey. you there?",
            choices: [
                TutorialChoice(label: "yeah, what's up", nextNode: 2),
                TutorialChoice(label: "...", nextNode: 3)
            ])

        // NODE 2 — responded
        n[2] = TutorialNode(id: 2, speaker: .alex,
            text: "good. didn't know if you'd actually answer.\nlisten — before we start, there's something you should know.",
            choices: [])

        // NODE 3 — silent
        n[3] = TutorialNode(id: 3, speaker: .alex,
            text: "okay. silent type. that's fine.\ni'll keep talking anyway.\nthere's something you need to know before we start.",
            choices: [])

        // NODE 4 — sound hint (auto after 2/3)
        n[4] = TutorialNode(id: 4, speaker: .system,
            text: "🔔  Turn your sound on.\n\nThis story breathes through its audio — ambient sounds, voice notes, and subtle cues are part of the experience. Silent mode will miss half of it.",
            choices: [
                TutorialChoice(label: "sound's on", nextNode: 5),
                TutorialChoice(label: "i'll play in silent mode", nextNode: 6)
            ])

        // NODE 5 — sound on
        n[5] = TutorialNode(id: 5, speaker: .alex,
            text: "perfect.\nthen you'll hear everything.",
            choices: [])

        // NODE 6 — silent mode
        n[6] = TutorialNode(id: 6, speaker: .alex,
            text: "your choice.\njust know — you might miss things.\nthings that matter.",
            choices: [])

        // NODE 7 — choices matter
        n[7] = TutorialNode(id: 7, speaker: .alex,
            text: "one more thing.\n\neverything you choose in this story — it changes things.\nwhat you say to me. what you ignore. how fast you reply.\nit all adds up.",
            choices: [
                TutorialChoice(label: "what happens if i make the wrong choice?", nextNode: 8),
                TutorialChoice(label: "got it. let's go.", nextNode: 9)
            ])

        // NODE 8 — wrong choice?
        n[8] = TutorialNode(id: 8, speaker: .alex,
            text: "wrong choice?\ni don't think there's such a thing.\njust... different outcomes.\nsome paths are harder. some are quieter.\nbut they're all real.",
            choices: [])

        // NODE 9 — ready
        n[9] = TutorialNode(id: 9, speaker: .alex,
            text: "okay.\ni like that energy.\nlet's see how far it takes you.",
            choices: [])

        // NODE 10 — end
        n[10] = TutorialNode(id: 10, speaker: .alex,
            text: "alright. i have to go.\nbut i'll text you later tonight.\ndon't fall asleep.",
            choices: [])

        return n
    }()

    // Auto-advance map: after displaying this node with no choices, go to next
    private let autoAdvance: [Int: Int] = [2: 4, 3: 4, 5: 7, 6: 7, 8: 10, 9: 10]

    // MARK: - State

    @State private var currentNodeId: Int = 1
    @State private var visibleMessages: [(id: UUID, speaker: Speaker, text: String)] = []
    @State private var showChoices: Bool = false
    @State private var screenOpacity: Double = 0
    @State private var isFinishing: Bool = false

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                header

                // Chat thread
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(visibleMessages, id: \.id) { msg in
                                messageRow(msg)
                                    .id(msg.id)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .onChange(of: visibleMessages.count) { _ in
                        if let last = visibleMessages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }

                // Choice keyboard
                if showChoices, let node = nodes[currentNodeId] {
                    choiceKeyboard(choices: node.choices)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .opacity(screenOpacity)
        .onAppear {
            withAnimation(.easeIn(duration: 0.6)) { screenOpacity = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                displayNode(id: 1)
            }
        }
    }

    // MARK: - Sub-views

    private var header: some View {
        HStack {
            Circle()
                .fill(Color(red: 0.545, green: 0, blue: 0))
                .frame(width: 36, height: 36)
                .overlay(
                    Text("A")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text("Alex")
                    .font(.system(size: 16, weight: .bold, design: .default))
                    .foregroundColor(.white)
                Text("Online")
                    .font(.system(size: 12))
                    .foregroundColor(.green)
            }
            Spacer()
            Text("TUTORIAL")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.3))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(red: 0.1, green: 0.07, blue: 0.07))
    }

    @ViewBuilder
    private func messageRow(_ msg: (id: UUID, speaker: Speaker, text: String)) -> some View {
        switch msg.speaker {
        case .alex:
            HStack(alignment: .bottom, spacing: 8) {
                Circle()
                    .fill(Color(red: 0.545, green: 0, blue: 0))
                    .frame(width: 28, height: 28)
                    .overlay(Text("A").font(.system(size: 12, weight: .bold)).foregroundColor(.white))
                Text(msg.text)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(red: 0.216, green: 0.2, blue: 0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .frame(maxWidth: 270, alignment: .leading)
                Spacer()
            }
        case .system:
            HStack {
                Spacer()
                Text(msg.text)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                    .frame(maxWidth: 300)
                Spacer()
            }
        }
    }

    private func choiceKeyboard(choices: [TutorialChoice]) -> some View {
        VStack(spacing: 0) {
            Divider().background(Color.white.opacity(0.1))
            ForEach(choices.indices, id: \.self) { i in
                let choice = choices[i]
                Button {
                    HapticManager.shared.playTypeHaptic()
                    handleChoice(choice)
                } label: {
                    Text(choice.label)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color(red: 0.12, green: 0.08, blue: 0.08))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background(Color(red: 0.96, green: 0.94, blue: 0.91))
                }
                .buttonStyle(.plain)
                if i < choices.count - 1 {
                    Divider().background(Color.black.opacity(0.15))
                }
            }
        }
        .background(Color(red: 0.96, green: 0.94, blue: 0.91))
    }

    // MARK: - Logic

    private func displayNode(id: Int) {
        guard let node = nodes[id] else { return }
        currentNodeId = id
        showChoices = false

        let newMsg = (id: UUID(), speaker: node.speaker, text: node.text)
        let typingDelay = min(0.4 + Double(node.text.count) * 0.012, 2.5)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation { visibleMessages.append(newMsg) }
            HapticManager.shared.playTypeHaptic()
        }

        if node.choices.isEmpty {
            // Auto-advance or end
            if let next = autoAdvance[id] {
                DispatchQueue.main.asyncAfter(deadline: .now() + typingDelay + 0.6) {
                    displayNode(id: next)
                }
            } else if id == 10 {
                // Final node — finish tutorial
                DispatchQueue.main.asyncAfter(deadline: .now() + typingDelay + 1.2) {
                    finishTutorial()
                }
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + typingDelay) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    showChoices = true
                }
            }
        }
    }

    private func handleChoice(_ choice: TutorialChoice) {
        withAnimation { showChoices = false }
        // Show player's reply as a right-side message
        let reply = (id: UUID(), speaker: Speaker.alex, text: choice.label)
        // Append player reply styled differently via isFromMe flag workaround:
        // We reuse .alex speaker but prepend a marker; for simplicity player
        // messages are shown as outgoing bubbles via a separate path below.
        let playerMsg = (id: UUID(), speaker: Speaker.system, text: choice.label)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation { visibleMessages.append(playerMsg) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                displayNode(id: choice.nextNode)
            }
        }
        _ = reply // suppress unused warning
    }

    private func finishTutorial() {
        guard !isFinishing else { return }
        isFinishing = true
        AppSettings.shared.hasSeenTutorial = true
        withAnimation(.easeIn(duration: 0.8)) { screenOpacity = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { onComplete() }
    }
}
