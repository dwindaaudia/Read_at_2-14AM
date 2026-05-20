import SwiftUI
import Combine

// MARK: - Manager

@MainActor
final class EvidenceBoardManager: ObservableObject {
    static let shared = EvidenceBoardManager()

    @Published var fragments: [EvidenceFragment] = EvidenceDatabase.all
    @Published var newFragmentID: String? = nil

    private let saveKey = "ra214_evidenceFragments"

    private init() { loadFromDisk() }

    /// Call from NarrativeState.didEnter() with the corresponding sceneID.
    func unlockFragment(forScene sceneID: String) {
        var changed = false
        for i in fragments.indices {
            if fragments[i].unlockedInScene == sceneID && !fragments[i].isUnlocked {
                fragments[i].isUnlocked = true
                newFragmentID = fragments[i].id
                changed = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                    if self.newFragmentID == self.fragments[i].id {
                        self.newFragmentID = nil
                    }
                }
            }
        }
        if changed { saveToDisk() }
    }

    func resetFragments() {
        fragments = EvidenceDatabase.all
        newFragmentID = nil
        saveToDisk()
    }

    var unlockedCount: Int { fragments.filter(\.isUnlocked).count }

    private func saveToDisk() {
        if let data = try? JSONEncoder().encode(fragments) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }

    private func loadFromDisk() {
        guard let data = UserDefaults.standard.data(forKey: saveKey),
              let saved = try? JSONDecoder().decode([EvidenceFragment].self, from: data) else { return }
        var merged = EvidenceDatabase.all
        for i in merged.indices {
            if let match = saved.first(where: { $0.id == merged[i].id }) {
                merged[i].isUnlocked = match.isUnlocked
            }
        }
        fragments = merged
    }
}
