import SwiftUI

// MARK: - Content View (Root)

struct ContentView: View {

    @StateObject private var gameManager = GameManager()
    @State private var currentScreen: AppScreen = .splash
    @State private var homeChatUnlocked = false
    /// Bumped whenever the player invokes "Reset All Game Data" so `HomescreenView` is rebuilt
    /// with fresh @State (intro animation, glitch timer, lock-feed snapshot).
    @State private var homeSessionID = UUID()
    @Environment(\.scenePhase) var scenePhase

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Group {
                switch currentScreen {

                case .splash:
                    SplashScreenView {
                        if GameSaveManager.shared.hasSave {
                            GameSaveManager.shared.restore(into: gameManager)
                            homeChatUnlocked = true
                        }
                        withAnimation(.easeIn(duration: 0.5)) {
                            currentScreen = .introVideo
                        }
                    }
                    .transition(.opacity)

                case .introVideo:
                    IntroVideoView {
                        withAnimation(.easeIn(duration: 0.5)) {
                            currentScreen = .home
                            AudioManager.shared.playBackgroundMusic(filename: "Horror")
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
                        GameSaveManager.shared.save(from: gameManager)
                        withAnimation(.easeIn(duration: 0.35)) {
                            currentScreen = .home
                            homeChatUnlocked = true
                        }
                    }
                    .transition(.opacity)
                }
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
                GameSaveManager.shared.save(from: gameManager)
                gameManager.scheduleHorrorNotification()
            } else if newPhase == .active {
                gameManager.cancelNotifications()
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
    }
}

#Preview {
    ContentView().preferredColorScheme(.dark)
}
