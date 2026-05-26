import SwiftUI

// MARK: - Content View (Root)

struct ContentView: View {

    @StateObject private var gameManager = GameManager()
    @State private var currentScreen: AppScreen = .introVideo
    @State private var homeChatUnlocked = false
    /// Bumped whenever the player invokes "Reset All Game Data" so `HomescreenView` is rebuilt
    /// with fresh @State (intro animation, glitch timer, lock-feed snapshot).
    @State private var homeSessionID = UUID()
    /// After backgrounding pre–first-choice, rebuild home at 2:13 on next foreground.
    @State private var rewindHomeOnNextActive = false
    @Environment(\.scenePhase) var scenePhase

    var body: some View {
        ZStack {
            Color(red: 0.11, green: 0.035, blue: 0.035).ignoresSafeArea()
            Group {
                switch currentScreen {

                
                case .introVideo:
                    IntroVideoView {
                        withAnimation(.easeIn(duration: 0.5)) {
                            routeAfterLogoIntro()
                        }
                    }
                    .transition(.opacity)

                case .titleVideo:
                    TitleVideoView {
                        withAnimation(.easeIn(duration: 0.5)) {
                            completeTitleVideoAndOpenHome()
                        }
                    }
                    .transition(.opacity)

                case .home:
                    HomescreenView(
                        gameManager: gameManager,
                        chatUnlocked: $homeChatUnlocked,
                        onOpenChat: {
                            if gameManager.messages.isEmpty {
                                gameManager.triggerInitialLockscreenEvent()
                            }
                            withAnimation(.easeIn(duration: 0.35)) {
                                currentScreen = .game
                            }
                        },
                        onResetAll: performFullReset
                    )
                    .id(homeSessionID)
                    .transition(.opacity)

                case .game:
                    ChatRoomView(gameManager: gameManager) {
                        homeChatUnlocked = AppSettings.shared.hasStartedGame
                            || AppSettings.shared.hasCompletedHome214Transition
                        withAnimation(.easeIn(duration: 0.35)) {
                            currentScreen = .home
                        }
                    }
                    .transition(.opacity)
                }
            }
        }
        .onAppear {
            if GameSaveManager.shared.hasSave {
                GameSaveManager.shared.restore(into: gameManager)
                homeChatUnlocked = true
            }
        }
        .onChange(of: currentScreen) { _, screen in
            if screen == .game {
                ChatNavigationBarStyler.applyOpaqueDarkBar()
            } else {
                ChatNavigationBarStyler.restoreDefaults()
            }
            if screen == .home {
                gameManager.resumePendingAlexReplyIfNeeded()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                if AppSettings.shared.hasStartedGame {
                    GameSaveManager.shared.save(from: gameManager)
                } else {
                    gameManager.revertToPreGameHomeHub()
                    GameSaveManager.shared.clearSave()
                    rewindHomeOnNextActive = true
                }
                gameManager.scheduleHorrorNotification()
            } else if newPhase == .active {
                gameManager.cancelNotifications()
                if rewindHomeOnNextActive {
                    rewindHomeOnNextActive = false
                    homeChatUnlocked = false
                    homeSessionID = UUID()
                    withAnimation(.easeIn(duration: 0.35)) {
                        openPreGameEntryScreen()
                    }
                }
                if currentScreen == .home {
                    gameManager.resumePendingAlexReplyIfNeeded()
                }
            }
        }
    }

    // MARK: - Reset
    /// Wipes save, evidence, totalClears, in-memory game state, and forces the home hub to
    /// rebuild with fresh @State so the new-player intro animation can replay.
    private func performFullReset() {
        gameManager.restartGame()
        GameSaveManager.shared.clearSave()
        EvidenceBoardManager.shared.resetFragments()
        AppSettings.shared.totalClears = 0
        homeChatUnlocked = false
        homeSessionID = UUID()
        AudioManager.shared.stopBackgroundMusic()
        withAnimation(.easeIn(duration: 0.5)) {
            currentScreen = .titleVideo
        }
    }

    /// Logo intro finished — skip title video if this pre-game session already saw it.
    private func routeAfterLogoIntro() {
        if AppSettings.shared.shouldShowTitleVideo {
            currentScreen = .titleVideo
        } else {
            completeTitleVideoAndOpenHome()
        }
    }

    private func completeTitleVideoAndOpenHome() {
        AppSettings.shared.markTitleVideoCompleted()
        currentScreen = .home
        AudioManager.shared.playBackgroundMusic(filename: "Horror")
    }

    /// Pre-game rewind (background) or reset — title video when appropriate, else home.
    private func openPreGameEntryScreen() {
        if AppSettings.shared.shouldShowTitleVideo {
            currentScreen = .titleVideo
            AudioManager.shared.stopBackgroundMusic()
        } else {
            completeTitleVideoAndOpenHome()
        }
    }
}

#Preview {
    ContentView().preferredColorScheme(.dark)
}
