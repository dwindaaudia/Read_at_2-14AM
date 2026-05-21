import SwiftUI
import AVKit

// MARK: - Intro Video Screen
// Letterboxed playback of `logo.mov` with a circular progress ring that tracks
// playback (0–100). When the video finishes, a "tap to start" prompt fades in
// and any tap on the screen continues to the home hub.

struct IntroVideoView: View {
    let onComplete: () -> Void

    @State private var player: AVPlayer?
    @State private var progress: Double = 0
    @State private var didFinishPlayback = false
    @State private var didComplete = false
    @State private var showMissingVideoMessage = false
    @State private var tapPromptOpacity: Double = 0
    @State private var timeObserverToken: Any?

    var body: some View {
        ZStack {
            Color(red: 0.11, green: 0.035, blue: 0.035).ignoresSafeArea()

            if let player {
                playerContent(player: player)
            } else if showMissingVideoMessage {
                missingVideoFallback
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { handleTap() }
        .task {
            loadPlayerIfNeeded()
        }
        .task(id: player) {
            await observePlaybackEnd()
        }
        .onDisappear {
            removeTimeObserver()
            player?.pause()
        }
    }

    // MARK: Subviews

    private func playerContent(player: AVPlayer) -> some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                Spacer(minLength: 0)

                IntroAVPlayerView(player: player)
                    .frame(width: proxy.size.width, height: proxy.size.height * 0.62)
                    .background(Color(red: 0.11, green: 0.035, blue: 0.035))

                VStack(spacing: 22) {
                    progressRing
                        .frame(width: 78, height: 78)

                    Text("tap to start")
                        .font(.system(size: 16, weight: .semibold))
                        .tracking(2)
                        .foregroundColor(.white)
                        .opacity(tapPromptOpacity)
                        .frame(height: 22)
                }
                .padding(.top, 36)

                Spacer(minLength: 0)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private var progressRing: some View {
        let clamped = min(max(progress, 0), 1)
        return ZStack {
            Circle()
                .stroke(Color.white.opacity(0.18), lineWidth: 4)

            Circle()
                .trim(from: 0, to: CGFloat(clamped))
                .stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.1), value: progress)

            Text("\(Int(clamped * 100))")
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
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

    // MARK: Playback

    private func loadPlayerIfNeeded() {
        guard player == nil else { return }

        let url = Bundle.main.url(forResource: "logo", withExtension: "mov")
        print("[IntroVideoView] logo.mov bundle URL: \(url?.path ?? "nil")")

        guard let url else {
            showMissingVideoMessage = true
            return
        }

        let player = AVPlayer(url: url)
        Task { await logAssetDiagnostics(for: url) }
        attachPeriodicTimeObserver(to: player)
        self.player = player
        player.play()
    }

    private func logAssetDiagnostics(for url: URL) async {
        let asset = AVURLAsset(url: url)
        do {
            let (isPlayable, duration, tracks) = try await asset.load(.isPlayable, .duration, .tracks)
            let videoTracks = tracks.filter { $0.mediaType == .video }
            print("[IntroVideoView] isPlayable=\(isPlayable) duration=\(duration.seconds) videoTracks=\(videoTracks.count)")
        } catch {
            print("[IntroVideoView] asset load failed: \(error)")
        }
    }

    private func attachPeriodicTimeObserver(to player: AVPlayer) {
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            guard let duration = player.currentItem?.duration.seconds,
                  duration.isFinite, duration > 0 else { return }
            let current = time.seconds
            progress = min(max(current / duration, 0), 1)
        }
    }

    private func removeTimeObserver() {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
    }

    private func observePlaybackEnd() async {
        guard let item = player?.currentItem else { return }

        for await _ in NotificationCenter.default.notifications(
            named: AVPlayerItem.didPlayToEndTimeNotification,
            object: item
        ) {
            handlePlaybackEnd()
            break
        }
    }

    private func handlePlaybackEnd() {
        guard !didFinishPlayback else { return }
        didFinishPlayback = true
        progress = 1
        withAnimation(.easeIn(duration: 0.8)) {
            tapPromptOpacity = 1
        }
    }

    private func handleTap() {
        guard didFinishPlayback else { return }
        HapticManager.shared.playTypeHaptic()
        completeIntro()
    }

    private func completeIntro() {
        guard !didComplete else { return }
        didComplete = true
        removeTimeObserver()
        player?.pause()
        onComplete()
    }
}

// MARK: - AVPlayer Bridge

private struct IntroAVPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspect
        controller.view.backgroundColor = UIColor(red: 0.11, green: 0.035, blue: 0.035, alpha: 1)
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        controller.player = player
    }
}
