import SwiftUI

// MARK: - TYPEWRITER TEXT

struct TypewriterText: View {
    let fullText: String
    var speed: TimeInterval = 0.03
    
    @State private var displayed: String = ""
    @State private var task: Task<Void, Never>? = nil
    
    var body: some View {
        Text(displayed)
            .onAppear { startTyping() }
            .onDisappear { task?.cancel() }
    }
    
    private func startTyping() {
        displayed = ""
        task?.cancel()
        task = Task {
            for char in fullText {
                if Task.isCancelled { break }
                await MainActor.run { displayed.append(char) }
                try? await Task.sleep(nanoseconds: UInt64(speed * 1_000_000_000))
            }
        }
    }
}
