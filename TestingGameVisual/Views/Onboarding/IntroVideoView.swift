import SwiftUI
import AVKit

struct IntroVideoView: View {
    let onComplete: () -> Void

    @State private var player: AVPlayer?
    @State private var didComplete = false
    @State private var showMissingVideoMessage = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player {
                IntroAVPlayerView(player: player)
                    .ignoresSafeArea()

                skipButton
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

    private var skipButton: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    completeIntro()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.black.opacity(0.42), in: Circle())
                }
                .accessibilityLabel("Skip intro")
            }
            .padding(.top, 18)
            .padding(.horizontal, 18)

            Spacer()
        }
    }

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

    private func loadPlayerIfNeeded() {
        guard player == nil else { return }

        guard let url = Bundle.main.url(forResource: "2.14AM", withExtension: "mov") else {
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

private struct IntroAVPlayerView: UIViewControllerRepresentable {
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
