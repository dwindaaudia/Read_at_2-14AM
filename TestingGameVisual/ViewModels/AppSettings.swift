import SwiftUI
import Combine
import AVFoundation

// MARK: - Persistent App Settings

final class AppSettings: ObservableObject {

    static let shared = AppSettings()

    // MARK: Published Properties

    @Published var musicVolume: Float {
        didSet {
            UserDefaults.standard.set(musicVolume, forKey: "ra214_musicVolume")
            AudioManager.shared.bgmPlayer?.volume = musicVolume
        }
    }

    @Published var sfxVolume: Float {
        didSet {
            UserDefaults.standard.set(sfxVolume, forKey: "ra214_sfxVolume")
            AudioManager.shared.applyCurrentSFXVolume()
        }
    }

    @Published var hapticsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(hapticsEnabled, forKey: "ra214_hapticsEnabled")
        }
    }

    /// True after the player sends their first chat choice — the run has actually started.
    @Published var hasStartedGame: Bool {
        didSet {
            UserDefaults.standard.set(hasStartedGame, forKey: "ra214_hasStartedGame")
        }
    }

    /// True after the home-screen 2:13 → 2:14 intro has played (tutorial dismiss or skip).
    @Published var hasCompletedHome214Transition: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedHome214Transition, forKey: "ra214_hasCompletedHome214Transition")
        }
    }

    /// True after `TitleVideoView` (2.14AM.mov) finishes for the current pre-game session.
    @Published var hasWatchedIntro: Bool {
        didSet {
            UserDefaults.standard.set(hasWatchedIntro, forKey: "hasWatchedIntro")
        }
    }

    /// Tutorial once before the first choice — not on every return to the home hub.
    var shouldShowTutorial: Bool {
        !hasStartedGame && !hasCompletedHome214Transition
    }

    /// Title video before home — not when returning from chat mid pre-game session.
    var shouldShowTitleVideo: Bool {
        !hasStartedGame && !hasWatchedIntro
    }

    @Published var debugBarVisible: Bool {
        didSet {
            UserDefaults.standard.set(debugBarVisible, forKey: "ra214_debugBarVisible")
        }
    }

    /// Completed runs (used for LLM loop / deja vu context).
    @Published var totalClears: Int {
        didSet {
            UserDefaults.standard.set(totalClears, forKey: "ra214_totalClears")
        }
    }

    // MARK: Init

    private init() {
        let ud = UserDefaults.standard
        musicVolume     = ud.object(forKey: "ra214_musicVolume")     as? Float ?? 0.5
        sfxVolume       = ud.object(forKey: "ra214_sfxVolume")       as? Float ?? 0.8
        hapticsEnabled  = ud.object(forKey: "ra214_hapticsEnabled")  as? Bool  ?? true
        if let started = ud.object(forKey: "ra214_hasStartedGame") as? Bool {
            hasStartedGame = started
        } else {
            hasStartedGame = false
        }

        if let completed = ud.object(forKey: "ra214_hasCompletedHome214Transition") as? Bool {
            hasCompletedHome214Transition = completed
        } else {
            // Legacy: dismissed tutorial implied the 2:14 home beat already ran.
            hasCompletedHome214Transition = ud.bool(forKey: "ra214_hasSeenTutorial")
        }
        hasWatchedIntro = ud.bool(forKey: "hasWatchedIntro")
        debugBarVisible = ud.object(forKey: "ra214_debugBarVisible") as? Bool  ?? false
        totalClears     = ud.object(forKey: "ra214_totalClears")     as? Int   ?? 0
    }

    // MARK: Actions

    func markGameStarted() {
        hasStartedGame = true
    }

    func markTitleVideoCompleted() {
        hasWatchedIntro = true
    }

    /// Rewinds pre-game session when the app leaves the foreground before the first choice.
    func revertPreGameSessionForAppExit() {
        hasCompletedHome214Transition = false
        hasWatchedIntro = false
    }

    /// Resets pre-game flags. Called from Settings reset and full game restart.
    func resetProgress() {
        hasStartedGame = false
        hasCompletedHome214Transition = false
        hasWatchedIntro = false
    }
}
