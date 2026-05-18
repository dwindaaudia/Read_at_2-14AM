import UIKit

// MARK: - Opaque navigation bar (no system glass) for chat

enum ChatNavigationBarStyler {
    static func applyOpaqueDarkBar() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.11, green: 0.0, blue: 0.02, alpha: 1.0)
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        let nav = UINavigationBar.appearance()
        nav.standardAppearance = appearance
        nav.compactAppearance = appearance
        nav.scrollEdgeAppearance = appearance
        nav.tintColor = .white
    }

    static func restoreDefaults() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        let nav = UINavigationBar.appearance()
        nav.standardAppearance = appearance
        nav.compactAppearance = appearance
        nav.scrollEdgeAppearance = appearance
        nav.tintColor = nil
    }
}
