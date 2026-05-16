import SwiftUI
import AVFoundation
import Combine

// MARK: - App Navigation Flow

enum AppScreen: Equatable {
    case splash
    case home
    case game
}

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

    @Published var hasSeenTutorial: Bool {
        didSet {
            UserDefaults.standard.set(hasSeenTutorial, forKey: "ra214_hasSeenTutorial")
        }
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
        hasSeenTutorial = ud.object(forKey: "ra214_hasSeenTutorial") as? Bool  ?? false
        debugBarVisible = ud.object(forKey: "ra214_debugBarVisible") as? Bool  ?? false
        totalClears     = ud.object(forKey: "ra214_totalClears")     as? Int   ?? 0
    }

    // MARK: Actions

    /// Resets tutorial progress. Called when "Reset Progress" is tapped in Settings.
    func resetProgress() {
        hasSeenTutorial = false
    }
}
