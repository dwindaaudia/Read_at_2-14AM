import SwiftUI

// MARK: - Content View (Root)

struct ContentView: View {

    @StateObject private var gameManager = GameManager()
    @State private var currentScreen: AppScreen = .splash
    @State private var isUnlocked = false
    @Environment(\.scenePhase) var scenePhase

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Group {
                switch currentScreen {

                case .splash:
                    SplashScreenView {
                        withAnimation(.easeIn(duration: 0.5)) {
                            currentScreen = .mainMenu
                            AudioManager.shared.playBackgroundMusic(filename: "Horror")
                        }
                    }
                    .transition(.opacity)

                case .mainMenu:
                    MainMenuView(
                        onNewGame: {
                            GameSaveManager.shared.clearSave()
                            EvidenceBoardManager.shared.resetFragments()
                            UnknownContactManager.shared.reset()
                            withAnimation(.easeIn(duration: 0.4)) { currentScreen = .contentWarning }
                        },
                        onContinue: {
                            GameSaveManager.shared.restore(into: gameManager)
                            isUnlocked = false
                            withAnimation(.easeIn(duration: 0.35)) { currentScreen = .game }
                        }
                    )
                    .transition(.opacity)

                case .contentWarning:
                    ContentWarningView {
                        withAnimation(.easeIn(duration: 0.4)) { currentScreen = .lockscreen }
                    }
                    .transition(.opacity)

                case .lockscreen:
                    LockScreenView(isUnlocked: $isUnlocked) {
                        gameManager.triggerInitialLockscreenEvent()
                    }
                    .onChange(of: isUnlocked) { _, unlocked in
                        if unlocked {
                            withAnimation(.easeIn(duration: 0.35)) { currentScreen = .game }
                        }
                    }
                    .transition(.opacity)

                case .game:
                    ChatRoomView(gameManager: gameManager) {
                        gameManager.restartGame()
                        isUnlocked = false
                        AudioManager.shared.stopBackgroundMusic()
                        AudioManager.shared.playBackgroundMusic(filename: "Horror")
                        withAnimation(.easeIn(duration: 0.5)) { currentScreen = .mainMenu }
                    }
                    .transition(.opacity)
                }
            }
            UnknownContactBannerView()
                .padding(.top, -400)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                GameSaveManager.shared.save(from: gameManager)
                gameManager.scheduleHorrorNotification()
            } else if newPhase == .active {
                gameManager.cancelNotifications()
            }
        }
    }
}

#Preview {
    ContentView().preferredColorScheme(.dark)
}
