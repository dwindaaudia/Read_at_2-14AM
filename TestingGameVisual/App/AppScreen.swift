import Foundation

// MARK: - App Navigation Flow
// Change the AppScreen to only contain splash home and game
enum AppScreen: Equatable {
    case splash
    case mainMenu
    case contentWarning
    case lockscreen
    case game
}
