import SwiftUI

// Banner shown at the top of the screen when a message arrives
struct UnknownContactBannerView: View {
    @ObservedObject private var manager = UnknownContactManager.shared

    var body: some View {
        if manager.showBanner {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color.red.opacity(0.15)).frame(width: 42, height: 42)
                    Text("?")
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundColor(.red)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("+62 000-0214")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Text(manager.bannerText)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(1)
                }
                Spacer()
                Text("2:14 AM")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(14)
            .background(.ultraThinMaterial)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.red.opacity(0.35), lineWidth: 1))
            .cornerRadius(16)
            .shadow(color: .red.opacity(0.25), radius: 14)
            .padding(.horizontal, 16)
            .padding(.top, 58)
            .transition(.move(edge: .top).combined(with: .opacity))
            .allowsHitTesting(false)
        }
    }
}
