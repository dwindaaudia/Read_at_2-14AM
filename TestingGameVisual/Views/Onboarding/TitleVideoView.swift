import SwiftUI
import AVKit

// MARK: - Title Video Screen
// Fullscreen playback of `2.14AM.mov` shown after the logo intro. Auto-advances
// to the home hub when the asset reaches the end.

struct TitleVideoView: View {
    let onComplete: () -> Void

    @State private var player: AVPlayer?
    @State private var didComplete = false
    @State private var showMissingVideoMessage = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player {
                TitleAVPlayerView(player: player)
                    .ignoresSafeArea()
            } else if showMissingVideoMessage {
                missingVideoFallback
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .task {
            loadPlayerIfNeeded()
        }
        .task(id: player) {
            await observePlaybackEnd()
        }
        .onDisappear {
            player?.pause()
        }
    }

    // MARK: Subviews

    private var missingVideoFallback: some View {
        VStack(spacing: 16) {
            Text("Intro video unavailable")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            Button("Continue") {
                completeIntro()
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.black)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.white, in: Capsule())
        }
        .padding()
    }

    // MARK: Playback

    private func loadPlayerIfNeeded() {
        guard player == nil else { return }

        let url = Bundle.main.url(forResource: "2.14AM", withExtension: "mov")
        print("[TitleVideoView] 2.14AM.mov bundle URL: \(url?.path ?? "nil")")

        guard let url else {
            showMissingVideoMessage = true
            return
        }

        let player = AVPlayer(url: url)
        self.player = player
        player.play()
    }

    private func observePlaybackEnd() async {
        guard let item = player?.currentItem else { return }

        for await _ in NotificationCenter.default.notifications(
            named: AVPlayerItem.didPlayToEndTimeNotification,
            object: item
        ) {
            completeIntro()
            break
        }
    }

    private func completeIntro() {
        guard !didComplete else { return }
        didComplete = true
        player?.pause()
        onComplete()
    }
}

// MARK: - AVPlayer Bridge

private struct TitleAVPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspectFill
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        controller.player = player
    }
}
