import SwiftUI

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
