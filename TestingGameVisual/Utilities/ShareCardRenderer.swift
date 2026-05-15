import SwiftUI
import UIKit

// MARK: - ENDING SHARE CARD

/// Rendered off-screen to produce a share image via ImageRenderer.
struct EndingShareCardView: View {
    let profile: (title: String, description: String, color: Color)

    var body: some View {
        ZStack {
            Color.black

            VStack(spacing: 0) {

                // Top accent line
                profile.color.opacity(0.7)
                    .frame(height: 3)

                VStack(spacing: 22) {

                    // Game title
                    VStack(spacing: 4) {
                        Text("READ AT 2:14 AM")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(.gray)
                            .tracking(4)
                        Text("A Psychological Horror Experience")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.gray.opacity(0.5))
                    }
                    .padding(.top, 28)

                    // Ending title
                    Text(profile.title)
                        .font(.system(size: 38, weight: .black))
                        .foregroundColor(profile.color)
                        .multilineTextAlignment(.center)

                    // Divider
                    profile.color.opacity(0.35).frame(height: 1).padding(.horizontal, 40)

                    // Description
                    Text(profile.description)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 24)

                    // Timestamp
                    Text("OCT 18, 2019  ·  02:14 AM")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.gray.opacity(0.5))
                        .padding(.bottom, 28)
                }

                // Bottom accent line
                profile.color.opacity(0.35).frame(height: 1)
            }
        }
        .frame(width: 320, height: 370)
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(profile.color.opacity(0.2), lineWidth: 1)
        )
    }
}

/// Renders the share card to a UIImage for sharing.
@available(iOS 16.0, *)
func renderShareCard(profile: (title: String, description: String, color: Color)) -> UIImage? {
    let renderer = ImageRenderer(content: EndingShareCardView(profile: profile))
    renderer.scale = 3.0
    return renderer.uiImage
}
