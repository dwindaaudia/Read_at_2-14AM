import SwiftUI

// MARK: - Evidence Board entry (toolbar button → Files screen)
// Kept under the "Evidence" view group because `EvidenceBoardManager` still
// drives the unread fragment indicator. The destination is now `FilesEvidenceView`.

struct EvidenceBoardButton: View {
    @ObservedObject private var board = EvidenceBoardManager.shared
    @ObservedObject var gameManager: GameManager
    @State private var showBoard = false

    var body: some View {
        Button(action: { showBoard = true }) {
            ZStack(alignment: .topTrailing) {
                Image("Library")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .foregroundColor(.white.opacity(0.9))
                if board.newFragmentID != nil {
                    Circle().fill(Color.red).frame(width: 9, height: 9)
                        .offset(x: 3, y: -3)
                }
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showBoard) {
            FilesEvidenceView(gameManager: gameManager)
        }
    }
}
