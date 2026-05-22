import SwiftUI

// MARK: - MESSAGE BUBBLE ENHANCED

/// System / ERROR lines: uneven per-character delays (machine "stutter") before the full line appears.
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
    private static let alexBubble = Color(red: 0.216, green: 0.2, blue: 0.2)
    private static let bubbleMax: CGFloat = 300

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
    }

    @ViewBuilder
    private var incomingRow: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Alex")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                HStack(alignment: .bottom, spacing: 4) {
                    incomingBubbleContent
                        .layoutPriority(1)
                    Text(message.time)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.white.opacity(0.65))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.bottom, 2)
                }
            }
            .frame(maxWidth: Self.bubbleMax, alignment: .leading)
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
                HStack(alignment: .bottom, spacing: 4) {
                    readMetaOutgoing
                        .padding(.bottom, 2)
                    outgoingBubbleContent
                }
                .frame(maxWidth: Self.bubbleMax, alignment: .trailing)
                .animation(.spring(response: 0.42, dampingFraction: 0.86), value: message.isRead)
            }
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
                .font(.helvetica(17))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(Rectangle().fill(Self.alexBubble))
                
//                .fixedSize(horizontal: false, vertical: true)
        case .image(let assetName):
            ImageLightboxView(assetName: assetName, caption: message.text, thumbnailCornerRadius: 0)
                .padding(6)
                .background(Rectangle().fill(Self.alexBubble))
        case .voiceNote(let id):
            VoiceNotePlayerBubble(filename: id, isFromMe: false, autoPlay: true)
        case .lockedFile(let id):
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "lock.doc.fill")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.9))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Hidden file")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white.opacity(0.9))
                        Text(id)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white.opacity(0.62))
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: Self.bubbleMax, alignment: .leading)
            .background(Self.alexBubble)
            .overlay(Rectangle().stroke(Color.white.opacity(0.08), lineWidth: 1))
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var outgoingBubbleContent: some View {
        switch message.type {
        case .text:
            Text(message.text)
                .font(.helvetica(17))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(Rectangle().fill(Self.youBubble))
                .fixedSize(horizontal: false, vertical: true)
        case .image(let assetName):
            ImageLightboxView(assetName: assetName, caption: message.text, thumbnailCornerRadius: 0)
                .fixedSize(horizontal: true, vertical: false)
        case .voiceNote(let id):
            VoiceNotePlayerBubble(filename: id, isFromMe: true, autoPlay: true)
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
//            .fixedSize(horizontal: true, vertical: true)
        default:
            EmptyView()
        }
    }
}
