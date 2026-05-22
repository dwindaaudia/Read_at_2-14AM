import SwiftUI

// MARK: - Choice Keyboard
// Inline strip above the composer: dark fill with red side bars per row.

struct ChoiceKeyboardView: View {
    let choices: [PlayerChoice]
    let denialScore: Int
    let onSelect: (PlayerChoice) -> Void

    /// Same accent red as the user message bubble (header / profile red family).
    private static let borderAccent = Color(red: 26 / 255.0, green: 8 / 255.0, blue: 8 / 255.0)
    private static let rowFill = Color(red: 182 / 255.0, green: 182 / 255.0, blue: 182 / 255.0)
    private static let textDark = Color(red: 28 / 255.0, green: 9 / 255.0, blue: 9 / 255.0)
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(choices) { choice in
                choiceButton(for: choice)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Each row height follows only that choice's text (1 line = short; 2+ lines = taller for that row only).
    private func choiceButton(for choice: PlayerChoice) -> some View {
        Button(action: { onSelect(choice) }) {
            Text(applyZalgo(to: choice.text, intensity: denialScore))
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Self.textDark)
                .multilineTextAlignment(.center)
                .lineLimit(6)
                .minimumScaleFactor(0.82)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 14)
                .padding(.vertical, 24)
                .background {
                    ZStack {
                        Self.rowFill
                        HStack(spacing: 0) {
                            
                            Spacer(minLength: 0)
                            
                        }
                    }
                }
                .overlay(
                    Rectangle()
                        .stroke(Color.black.opacity(1), lineWidth: 3)
                )
        }
        .buttonStyle(.plain)
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
