import SwiftUI

// ── Alex Notifications ──────────────────────────────────────────────────────
struct AlexNotificationCard: View {
    let message: String
    let time: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            // Ikon Pengirim (Alex)
            Image(systemName: "person.circle.fill")
                .resizable()
                .frame(width: 40, height: 40)
                .foregroundColor(.white.opacity(0.8))
                .padding(.top, 5)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("ALEX")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundColor(.red.opacity(0.9))
                    
                    Spacer()
                    
                    Text(time)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.gray)
                }
                
                Text(message)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(15)
        .background(
            // Efek kaca transparan (Glassmorphism)
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .padding(.horizontal, 25)
        .padding(.vertical, 5)
    }
}
