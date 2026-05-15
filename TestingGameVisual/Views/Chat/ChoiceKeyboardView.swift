import SwiftUI

// MARK: - Choice Keyboard

struct ChoiceKeyboardView: View {
    let choices: [PlayerChoice]
    let denialScore: Int
    let onSelect: (PlayerChoice) -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Capsule().fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 5).padding(.top, 8)
            
            VStack(spacing: 8) {
                ForEach(choices) { choice in
                    Button(action: { onSelect(choice) }) {
                        Text(applyZalgo(to: choice.text, intensity: denialScore))
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.3))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
                            )
                            .padding(.horizontal)
                    }
                }
            }
            .padding(.bottom, 30)
        }
        .frame(maxWidth: .infinity)
        .background(Color.red.opacity(0.45))
        .cornerRadius(20, corners: [.topLeft, .topRight])
        .shadow(radius: 10)
    }
    
    /// Applies Zalgo-style diacritic corruption when denial score exceeds 10.
    private func applyZalgo(to text: String, intensity: Int) -> String {
        guard intensity > 10 else { return text }
        
        let zalgoMarks = [
            "\u{030d}", "\u{030e}", "\u{0304}", "\u{0305}", "\u{033f}", "\u{0311}",
            "\u{0306}", "\u{0310}", "\u{0352}", "\u{0357}", "\u{0351}", "\u{0301}",
            "\u{0300}", "\u{0316}", "\u{0317}", "\u{0318}", "\u{0319}", "\u{031c}",
            "\u{031d}", "\u{0324}", "\u{0325}", "\u{0326}", "\u{032e}", "\u{032f}",
            "\u{0330}", "\u{0331}", "\u{0332}", "\u{0333}", "\u{0339}", "\u{033a}",
            "\u{033b}", "\u{033c}", "\u{0345}", "\u{0347}", "\u{0348}", "\u{0349}",
            "\u{034a}", "\u{034b}", "\u{034c}", "\u{034d}", "\u{034e}", "\u{0353}",
            "\u{0354}", "\u{0355}", "\u{0356}", "\u{0359}", "\u{035a}", "\u{0323}"
        ]
        
        var result = ""
        for char in text {
            result.append(char)
            if char.isWhitespace { continue }
            
            let marksCount = intensity > 15 ? Int.random(in: 1...3) : Int.random(in: 0...1)
            for _ in 0..<marksCount {
                if let mark = zalgoMarks.randomElement() {
                    result.append(Character(UnicodeScalar(mark)!))
                }
            }
        }
        return result
    }
}
