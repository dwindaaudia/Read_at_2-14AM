import SwiftUI

// MARK: - Files screen (replaces the old cork-board EvidenceBoardView)
// Shows the player every Alex-side photo / voice / archive file the chat has surfaced.
// Visual rules:
// • Sharp-rectangle cards, uniform photo crop, Helvetica throughout.
// • Custom dark header (matches ChatRoomView) — no native nav bar / Liquid Glass.

struct FilesEvidenceView: View {
    @ObservedObject var gameManager: GameManager
    @Environment(\.dismiss) private var dismiss

    private static let bgMaroon = Color(red: 0.07, green: 0.0, blue: 0.0)

    private var headerBar: LinearGradient {
        // Translating Hex #600606 to RGB
        let baseColor = Color(red: 96 / 255.0, green: 6 / 255.0, blue: 6 / 255.0)
        
        return LinearGradient(
            gradient: Gradient(colors: [
                baseColor.opacity(0.0), // Top: 0% opacity
                baseColor.opacity(1.0)  // Bottom: 100% opacity
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
    }
    private static let cardOrange = Color(red: 169 / 255.0, green: 169 / 255.0, blue: 169 / 255.0)
    private static let accentMaroon = Color(red: 0.29, green: 0.0, blue: 0.0)

    private var alexFiles: [AlexStoryFileItem] {
        gameManager.messages.compactMap { msg -> AlexStoryFileItem? in
            guard !msg.isFromMe else { return nil }
            switch msg.type {
            case .image(let name):
                return AlexStoryFileItem(id: msg.id, message: msg, displayName: Self.imageDisplayName(name), kind: .photo)
            case .voiceNote(let fn):
                return AlexStoryFileItem(id: msg.id, message: msg, displayName: fn.uppercased(), kind: .voice)
            case .lockedFile(let id):
                return AlexStoryFileItem(id: msg.id, message: msg, displayName: id, kind: .archive)
            default:
                return nil
            }
        }
    }

    private var chapterBuckets: [(title: String, items: [AlexStoryFileItem])] {
        let items = alexFiles
        guard !items.isEmpty else { return [] }
        return [("Chapter 1", items)]
    }

    var body: some View {
        // ZStack utama bisa dihapus, langsung gunakan VStack sebagai kontainer utama
        VStack(spacing: 0) {
            customHeader
            
            if alexFiles.isEmpty {
                ScrollView {
                    Text("No file found.")
                        .font(.helvetica(17, weight: .medium))
                        .foregroundColor(.white.opacity(0.55))
                        .frame(maxWidth: .infinity, minHeight: 200)
                }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        ForEach(chapterBuckets, id: \.title) { bucket in
                            Text(bucket.title)
                                .font(.helvetica(18, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.top, 25)
                            
                            LazyVGrid(
                                columns: [
                                    GridItem(.flexible(), spacing: 10),
                                    GridItem(.flexible(), spacing: 10),
                                    GridItem(.flexible(), spacing: 10)
                                ],
                                spacing: 10
                            ) {
                                ForEach(bucket.items) { item in
                                    InteractiveStoryFileCard(
                                        item: item,
                                        gameManager: gameManager,
                                        cardOrange: Self.cardOrange,
                                        accentMaroon: Self.accentMaroon
                                    )
                                }
                            }
                            .padding(.horizontal, 12)
                        }
                    }
                    .padding(.bottom, 28)
                }
            }
        }
        // MARK: - Terapkan Background di Sini
        .background {
            ZStack {
                // 1. Warna dasar paling bawah
                Self.bgMaroon
                
                Image("red-overlay")
                    .resizable()
                    .scaledToFill()
                
                Color.black
                    .opacity(0.7)
            }
            .ignoresSafeArea()
        }
        .preferredColorScheme(.dark)
        
        .toolbar(.hidden, for: .navigationBar)
        
        .simultaneousGesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .global)
                .onEnded { value in
                    let horizontalSwipe = value.translation.width
                    let predictedHorizontal = value.predictedEndTranslation.width
                    let verticalSwipe = abs(value.translation.height)
                    
                    if (horizontalSwipe > 50 || predictedHorizontal > 150) && verticalSwipe < 60 {
                        HapticManager.shared.playTypeHaptic()
                        dismiss()
                    }
                }
        )
    }

    // MARK: Custom Header (matches ChatRoomView)

    private var customHeader: some View {
            ZStack(alignment: .center) {
                // 1. The Title (Perfectly centered in the ZStack)
                Text("Files")
                    .font(.helvetica(35, weight: .bold))
                    .foregroundColor(.white)

                // 2. The Leading Buttons (Pushed to the left)
                HStack(alignment: .center, spacing: 0) {
                    Button {
                        HapticManager.shared.playTypeHaptic()
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back")

                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 25)
            .background(headerBar)
        }

    private static func imageDisplayName(_ asset: String) -> String {
        let lower = asset.lowercased()
        if lower.contains("img02") || lower.contains("img_02") { return "IMG_02.jpg" }
        if lower.contains("alex") || lower.contains("friend") { return "IMG_01.jpg" }
        let safe = asset.replacingOccurrences(of: " ", with: "_")
        return "\(safe).jpg"
    }
}

// MARK: - Interactive file card

private struct InteractiveStoryFileCard: View {
    let item: AlexStoryFileItem
    @ObservedObject var gameManager: GameManager
    let cardOrange: Color
    let accentMaroon: Color

    @State private var showImageViewer = false
    @State private var showVoicePlayer = false
    @State private var showDecryptTheatre = false

    var body: some View {
        Button {
            handleTap()
        } label: {
            StoryFileCardVisual(
                displayName: item.displayName,
                kind: item.kind,
                cardOrange: cardOrange,
                accentMaroon: accentMaroon,
                imageAssetName: imageAssetName
            )
        }
        .buttonStyle(.plain)
        .fullScreenCover(isPresented: $showImageViewer) {
            if let name = imageAssetName {
                FileImageViewerSheet(
                    assetName: name,
                    caption: item.message.text,
                    time: item.message.time
                )
            }
        }
        .sheet(isPresented: $showVoicePlayer) {
            if let fn = voiceFilename {
                FileVoicePlayerSheet(filename: fn, time: item.message.time)
            }
        }
        .fullScreenCover(isPresented: $showDecryptTheatre) {
            CorruptedDecryptTheatreView()
        }
    }

    private var imageAssetName: String? {
        if case .image(let n) = item.message.type { return n }
        return nil
    }

    private var voiceFilename: String? {
        if case .voiceNote(let f) = item.message.type { return f }
        return nil
    }

    private func handleTap() {
        HapticManager.shared.playTypeHaptic()
        switch item.kind {
        case .photo:
            guard imageAssetName != nil else { return }
            showImageViewer = true
        case .voice:
            guard voiceFilename != nil else { return }
            showVoicePlayer = true
        case .archive:
            showDecryptTheatre = true
        }
    }
}

private struct StoryFileCardVisual: View {
    let displayName: String
    let kind: AlexStoryFileKind
    let cardOrange: Color
    let accentMaroon: Color
    var imageAssetName: String? = nil

    /// Fixed media area height — all cards (photo / voice / archive) share the same crop window.
    private let mediaHeight: CGFloat = 100

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if kind == .photo, let img = imageAssetName {
                    // Color.clear takes the parent's full frame, image .fill-renders into the overlay,
                    // outer .clipped() crops anything that overflows. Standard SwiftUI tile-crop idiom.
                    Color.clear
                        .overlay(
                            Image(img)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        )
                } else {
                    cardOrange
                    Image(systemName: iconName)
                        .font(.system(size: 36, weight: .medium))
                        .foregroundColor(accentMaroon)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: mediaHeight)
            .clipped()

            Text(displayName)
                .font(.helvetica(11, weight: .semibold))
                .foregroundColor(accentMaroon)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
                .background(cardOrange.opacity(0.72))
        }
        .clipShape(Rectangle())
        .overlay(
            Rectangle()
                .stroke(Color.black.opacity(0.12), lineWidth: 1)
        )
    }

    private var iconName: String {
        switch kind {
        case .photo:   return "photo.on.rectangle.angled"
        case .voice:   return "speaker.wave.2.fill"
        // `doc.zipper.fill` doesn't exist in SF Symbols; archivebox.fill is the canonical archive glyph.
        case .archive: return "zipper.page"
        }
    }
}

// MARK: - Photo viewer (full screen)

private struct FileImageViewerSheet: View {
    let assetName: String
    let caption: String
    let time: String
    @Environment(\.dismiss) private var dismiss
    @State private var magnification: CGFloat = 1.0
    @State private var baseMagnification: CGFloat = 1.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.white.opacity(0.12), in: Circle())
                    }
                    Spacer()
                    Text("Pinch to zoom")
                        .font(.helvetica(12, weight: .medium))
                        .foregroundColor(.white.opacity(0.45))
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 8)
                .padding(.top, 12)

                Spacer(minLength: 8)

                Image(assetName)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(magnification)
                    .animation(.interactiveSpring(), value: magnification)
                    .padding(.horizontal, 12)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                let next = baseMagnification * value
                                magnification = min(max(next, 1.0), 4.0)
                            }
                            .onEnded { _ in
                                baseMagnification = magnification
                            }
                    )

                if !caption.isEmpty {
                    Text(caption)
                        .font(.helvetica(14))
                        .foregroundColor(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .padding()
                }

                Text(time)
                    .font(.helvetica(12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.bottom, 8)

                Spacer(minLength: 24)
            }
        }
    }
}

// MARK: - Voice note sheet

private struct FileVoicePlayerSheet: View {
    let filename: String
    let time: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0, blue: 0.01).ignoresSafeArea()

            VStack(spacing: 0) {
                voiceSheetHeader

                VStack(spacing: 18) {
                    Text(filename)
                        .font(.helvetica(14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))

                    Text(time)
                        .font(.helvetica(12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.55))

                    VoiceNotePlayerBubble(filename: filename, isFromMe: false)
                        .padding(.horizontal, 20)
                }
                .padding(.top, 24)

                Spacer(minLength: 0)
            }
        }
        .presentationDetents([.medium])
    }

    private var voiceSheetHeader: some View {
        HStack(alignment: .center, spacing: 0) {
            Button {
                HapticManager.shared.playTypeHaptic()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            Rectangle()
                .fill(Color.white.opacity(0.22))
                .frame(width: 1, height: 28)
                .padding(.horizontal, 8)

            Text("Voice note")
                .font(.helvetica(17, weight: .bold))
                .foregroundColor(.white)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .background(Color(red: 0.1, green: 0, blue: 0.02))
    }
}
