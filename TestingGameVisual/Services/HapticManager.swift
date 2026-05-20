import UIKit

// MARK: - Hardware Controllers
// ─────────────────────────────────────────────────────────────────────────────

class HapticManager {
    static let shared = HapticManager()
    
    func playGlitchHaptic() {
        guard AppSettings.shared.hapticsEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }
    
    func playTypeHaptic() {
        guard AppSettings.shared.hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
