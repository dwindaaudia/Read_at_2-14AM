import SwiftUI

// MARK: - FAKE STATUS BAR

struct FakeStatusBarView: View {
    let time: String
    let batteryLevel: Double
    let denialScore: Int

    var body: some View {
        HStack {
            Text(time)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)

            Spacer()

            HStack(spacing: 4) {
                Text("\(Int(batteryLevel))%")
                    .font(.system(size: 12, design: .monospaced))

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color.white.opacity(0.4), lineWidth: 1)
                        .frame(width: 20, height: 10)

                    RoundedRectangle(cornerRadius: 1)
                        .fill(batteryLevel < 20 ? Color.red : Color.white)
                        .frame(width: CGFloat(batteryLevel / 100 * 18), height: 8)
                        .padding(.leading, 1)
                }
            }
            .foregroundColor(batteryLevel < 20 ? .red : .white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.5))
    }
}
