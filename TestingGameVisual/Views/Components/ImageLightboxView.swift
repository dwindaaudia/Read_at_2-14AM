import SwiftUI

// MARK: - IMAGE LIGHTBOX

struct ImageLightboxView: View {
    let assetName: String
    let caption: String
    /// Chat uses sharp corners; evidence log keeps default.
    var thumbnailCornerRadius: CGFloat = 12

    @State private var isExpanded = false
    @State private var scale: CGFloat = 1.0
    @Namespace private var ns

    private var captionBackground: Color {
        // In chat (sharp corners) the image sits inside a colored message bubble;
        // let the bubble color show through so the caption blends with the bubble.
        thumbnailCornerRadius <= 4 ? Color.clear : Color(UIColor.secondarySystemBackground)
    }

    private var captionForeground: Color {
        thumbnailCornerRadius <= 4 ? Color.white.opacity(0.85) : Color.primary
    }

    var body: some View {
        ZStack {
            if !isExpanded {
                thumbnail
                    .matchedGeometryEffect(id: "img_\(assetName)", in: ns)
            }
            if isExpanded {
                fullscreenOverlay
            }
        }
    }

    private var thumbnail: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomTrailing) {
                Image(assetName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 240, height: 180)
                    .clipped()

                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.caption)
                    .padding(6)
                    .background(Color.black.opacity(0.6), in: Circle())
                    .foregroundColor(.white)
                    .padding(8)
            }

            if !caption.isEmpty {
                Text(caption)
                    .font(.caption)
                    .foregroundColor(captionForeground)
                    .padding(10)
                    .frame(maxWidth: 240, alignment: .leading)
                    .background(captionBackground)
            }
        }
        .cornerRadius(thumbnailCornerRadius)
        .onTapGesture {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                isExpanded = true
            }
            HapticManager.shared.playTypeHaptic()
        }
    }

    private var fullscreenOverlay: some View {
        ZStack {
            Color.black.opacity(0.95)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        isExpanded = false
                        scale = 1.0
                    }
                }

            VStack(spacing: 16) {
                HStack {
                    Spacer()
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            isExpanded = false
                            scale = 1.0
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.white.opacity(0.15), in: Circle())
                    }
                    .padding()
                }

                Spacer()

                Image(assetName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .matchedGeometryEffect(id: "img_\(assetName)", in: ns)
                    .scaleEffect(scale)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { scale = $0 }
                            .onEnded { _ in
                                withAnimation { scale = max(1.0, min(scale, 4.0)) }
                            }
                    )
                    .padding()

                if !caption.isEmpty {
                    Text(caption)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal)
                }

                HStack(spacing: 16) {
                    Label("Oct 18, 2019", systemImage: "calendar")
                    Label("2:14 AM", systemImage: "clock")
                }
                .font(.caption.monospaced())
                .foregroundColor(.gray)
                .padding(.bottom, 40)
            }
        }
        .transition(.opacity)
        .zIndex(999)
    }
}
