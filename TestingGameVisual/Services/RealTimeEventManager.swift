import SwiftUI

// MARK: - REAL-TIME 2:14 AM EVENT
// Meta-horror: the game detects the real device clock.
// If the player opens the app at exactly 2:14 AM, Alex immediately knows —
// and sends a sequence of messages that will not appear at any other time.

struct RealTimeEventManager {
    static var isThe214Moment: Bool {
        let cal = Calendar.current
        let now = Date()
        return cal.component(.hour, from: now) == 2
            && cal.component(.minute, from: now) == 14
    }

    static let specialMessages: [(delay: Double, text: String)] = [
        (1.0,  "wait"),
        (3.0,  "it's 2:14"),
        (5.5,  "why are you awake right now"),
        (8.0,  "you opened this at the exact moment i disappeared"),
        (11.0, "that's not a coincidence"),
        (14.0, "you never forgot, did you"),
    ]
}

struct RealTimeEventModifier: ViewModifier {
    @ObservedObject var manager: GameManager
    @State private var hasChecked = false

    func body(content: Content) -> some View {
        content.onAppear {
            guard !hasChecked else { return }
            hasChecked = true
            guard RealTimeEventManager.isThe214Moment else { return }

            for item in RealTimeEventManager.specialMessages {
                DispatchQueue.main.asyncAfter(deadline: .now() + item.delay + 2.0) {
                    manager.addAlexMessage(item.text, type: .text)
                }
            }

            // Glitch burst at the end of the sequence
            let finalDelay = (RealTimeEventManager.specialMessages.last?.delay ?? 14) + 3.5
            DispatchQueue.main.asyncAfter(deadline: .now() + finalDelay) {
                manager.glitchTrigger += 4
                HapticManager.shared.playGlitchHaptic()
                AudioManager.shared.playSound("static_sfx")
            }
        }
    }
}

extension View {
    /// Attach to the main chat view: `.checkRealTimeEvent(manager: manager)`
    func checkRealTimeEvent(manager: GameManager) -> some View {
        modifier(RealTimeEventModifier(manager: manager))
    }
}
