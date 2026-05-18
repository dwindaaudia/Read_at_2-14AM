import SwiftUI

// ── Alex Notification Card ──────────────────────────────────────────────────
// Lock-screen-style card. Becomes a tap target only when `isInteractive` is true
// and `onTap` is provided (e.g. the chat is unlocked from `HomescreenView`).

struct AlexNotificationCard: View {
    let message: String
    let time: String
    var isInteractive: Bool = true
    var onTap: (() -> Void)? = nil

    var body: some View {
        Group {
            if let onTap, isInteractive {
                Button(action: onTap) { cardContent }
                    .buttonStyle(.plain)
            } else {
                cardContent
            }
        }
        .opacity(isInteractive ? 1 : 0.5)
    }

    private var cardContent: some View {
        HStack(alignment: .top, spacing: 15) {
            Image("alex pp")
                .resizable()
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Alex")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)

                    Spacer()

                    Text(time)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                }

                Text(message)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(15)
        .background(Color.red.opacity(0.25))
        .overlay(
            VStack {
                Rectangle()
                    .fill(Color.red.opacity(0.5))
                    .frame(height: 1)

                Spacer()

                Rectangle()
                    .fill(Color.red.opacity(0.5))
                    .frame(height: 1)
            }
        )
        .padding(.horizontal, 25)
        .padding(.vertical, 5)
    }
}
