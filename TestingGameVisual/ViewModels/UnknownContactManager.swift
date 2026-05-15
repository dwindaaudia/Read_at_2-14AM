import SwiftUI
import Combine

@MainActor
final class UnknownContactManager: ObservableObject {
    static let shared = UnknownContactManager()

    @Published var messages:   [UnknownMessage] = []
    @Published var hasUnread:  Bool = false
    @Published var showBanner: Bool = false
    @Published var bannerText: String = ""

    private let saveKey    = "ra214_unknownMsgs"
    private let indicesKey = "ra214_unknownIdx"

    // Messages with their minimum denialScore threshold
    private let pool: [(minDenial: Int, text: String)] = [
        (5,  "don't trust him"),
        (5,  "he's still at the bridge"),
        (5,  "you should have answered"),
        (8,  "2:14. that's when it happened"),
        (8,  "he called you first"),
        (8,  "i was there that night"),
        (10, "this is a loop. you've done this before"),
        (10, "he didn't fall. he waited"),
        (12, "you're the reason he's stuck"),
        (12, "stop denying. you know what happened"),
        (15, "he can't leave until YOU remember"),
        (15, "you missed his call. then you missed him"),
        (18, "this is the 4,392nd time you've read this"),
        (18, "YOU ARE NOW IN THE QUEUE"),
    ]
    private var usedIndices: Set<Int> = []

    private init() { restoreState() }

    func saveState() {
        if let d1 = try? JSONEncoder().encode(messages) {
            UserDefaults.standard.set(d1, forKey: saveKey)
        }
        if let d2 = try? JSONEncoder().encode(usedIndices) {
            UserDefaults.standard.set(d2, forKey: indicesKey)
        }
    }

    func restoreState() {
        if let d1 = UserDefaults.standard.data(forKey: saveKey),
           let s1 = try? JSONDecoder().decode([UnknownMessage].self, from: d1) {
            messages = s1
        }
        if let d2 = UserDefaults.standard.data(forKey: indicesKey),
           let s2 = try? JSONDecoder().decode(Set<Int>.self, from: d2) {
            usedIndices = s2
        }
    }

    func checkAndSchedule(denialScore: Int) {
        guard denialScore >= 5 else { return }
        let delay = Double.random(in: 20...60)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.fire(denialScore: denialScore)
        }
    }

    private func fire(denialScore: Int) {
        let eligible = pool.enumerated().filter {
            $0.element.minDenial <= denialScore && !usedIndices.contains($0.offset)
        }
        guard let pick = eligible.randomElement() else { return }
        usedIndices.insert(pick.offset)

        let text = pick.element.text

        bannerText = text
        withAnimation(.spring(response: 0.4)) { showBanner = true }
        AudioManager.shared.playSound("notification_sfx")
        HapticManager.shared.playGlitchHaptic()

        DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
            withAnimation { self.showBanner = false }
            self.messages.append(UnknownMessage(text: text))
            self.hasUnread = true
            self.saveState()
        }
    }

    func markRead() { hasUnread = false }

    func reset() {
        messages = []; hasUnread = false
        usedIndices = []; showBanner = false
    }
}
