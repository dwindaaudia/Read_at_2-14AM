import SwiftUI
import AVFoundation
import Combine

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
        guard let url = AudioManager.audioResourceURL(for: filename) else {
            print("VoiceNoteAudioController: file '\(filename)' not found.")
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
        // Audit fix: volume is applied once when playback starts (see `play(filename:)`),
        // not on every 20Hz tick. The Settings sheet rarely opens during voice-note playback;
        // if the user *does* change SFX volume mid-playback, the change applies on the next play.
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self else { return }
            DispatchQueue.main.async {
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
