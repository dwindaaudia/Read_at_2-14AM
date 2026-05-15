import AVFoundation

// MARK: - Audio Manager
// Multi-channel SFX pool so heartbeat and other sounds can overlap.
// `applyCurrentSFXVolume()` is called whenever sfxVolume changes in Settings.

class AudioManager {
    static let shared = AudioManager()
    
    var bgmPlayer: AVAudioPlayer?
    
    /// SFX pool — allows concurrent sounds without one cutting another off.
    private var sfxPool: [AVAudioPlayer] = []
    private let poolSize = 6
    
    private init() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("AudioManager: Failed to configure audio session — \(error)")
        }
    }
    
    /// Compatibility accessor for external code that still references sfxPlayer.
    var sfxPlayer: AVAudioPlayer? { sfxPool.first }
    
    // MARK: BGM
    
    func playBackgroundMusic(filename: String) {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "mp3") else {
            print("AudioManager: BGM file '\(filename).mp3' not found.")
            return
        }
        do {
            bgmPlayer = try AVAudioPlayer(contentsOf: url)
            bgmPlayer?.numberOfLoops = -1
            bgmPlayer?.volume = AppSettings.shared.musicVolume
            bgmPlayer?.prepareToPlay()
            bgmPlayer?.play()
        } catch {
            print("AudioManager: Failed to play BGM — \(error)")
        }
    }
    
    func stopBackgroundMusic() {
        bgmPlayer?.stop()
    }
    
    // MARK: SFX
    // Each call picks a free slot from the pool (or evicts the oldest)
    // so multiple sounds can play simultaneously.
    
    func playSound(_ filename: String) {
        let name = filename.replacingOccurrences(of: ".mp3", with: "")
        guard let url = Bundle.main.url(forResource: name, withExtension: "mp3") else {
            print("AudioManager: SFX file '\(name).mp3' not found.")
            return
        }

        if let free = sfxPool.first(where: { !$0.isPlaying }),
           let newPlayer = try? AVAudioPlayer(contentsOf: url),
           let idx = sfxPool.firstIndex(of: free) {
            sfxPool[idx] = newPlayer
            newPlayer.volume = AppSettings.shared.sfxVolume
            newPlayer.prepareToPlay()
            newPlayer.play()
        } else if sfxPool.count < poolSize,
                  let newPlayer = try? AVAudioPlayer(contentsOf: url) {
            sfxPool.append(newPlayer)
            newPlayer.volume = AppSettings.shared.sfxVolume
            newPlayer.prepareToPlay()
            newPlayer.play()
        } else if let newPlayer = try? AVAudioPlayer(contentsOf: url) {
            // Pool full — evict oldest slot
            sfxPool[0].stop()
            sfxPool[0] = newPlayer
            newPlayer.volume = AppSettings.shared.sfxVolume
            newPlayer.prepareToPlay()
            newPlayer.play()
        }
    }
    
    /// Applies the current sfxVolume to all active pool players.
    /// Called whenever AppSettings.sfxVolume changes.
    func applyCurrentSFXVolume() {
        let vol = AppSettings.shared.sfxVolume
        sfxPool.forEach { $0.volume = vol }
    }
}
