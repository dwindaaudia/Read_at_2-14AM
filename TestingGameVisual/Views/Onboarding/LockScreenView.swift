import SwiftUI

// MARK: Lock Screen

struct LockScreenView: View {
    @Binding var isUnlocked: Bool
    let onAppearAction: () -> Void
    
    @State private var timeString = "2:13"
    @State private var showGhostNotifications = true
    @State private var brightnessDim: Double = 0.0
    @State private var glitchOpacity: Double = 0.0
    @State private var showAlexNotification = false
    @State private var canUnlock = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Color(white: 0.1).ignoresSafeArea()
            Color.black.opacity(brightnessDim).ignoresSafeArea()
            Color.red.opacity(glitchOpacity).ignoresSafeArea()
            
            VStack {
                VStack(spacing: 0) {
                    Text(timeString)
                        .font(.system(size: 80, weight: .thin, design: .rounded))
                        .foregroundColor(.white)
                    Text("Friday, October 18")
                        .font(.headline).foregroundColor(.white.opacity(0.8))
                }
                .padding(.top, 40)
                
                Spacer()
                
                if showGhostNotifications {
                    VStack(spacing: 8) {
                        NotificationChip(title: "Instagram", message: "Someone liked your photo")
                        NotificationChip(title: "WhatsApp",  message: "Mom: Are you coming home?")
                        NotificationChip(title: "System",    message: "Storage almost full")
                    }
                    .transition(.opacity)
                    .padding(.horizontal)
                }
                
                if showAlexNotification {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "message.fill").foregroundColor(.green)
                            Text("MESSAGES").font(.caption).fontWeight(.bold).foregroundColor(.gray)
                            Spacer()
                            Text("Now").font(.caption).foregroundColor(.gray)
                        }
                        Text("Alex").font(.headline).foregroundColor(.white)
                        Text("Are you awake?").font(.subheadline).foregroundColor(.white.opacity(0.9))
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(18)
                    .padding(.horizontal)
                    .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
                    .onTapGesture {
                        if canUnlock {
                            HapticManager.shared.playTypeHaptic()
                            withAnimation(.spring()) { isUnlocked = true }
                        }
                    }
                }
                
                Spacer()
                
                if canUnlock {
                    Text("Swipe up or tap notification to open")
                        .font(.caption).foregroundColor(.white.opacity(0.4))
                        .padding(.bottom, 30)
                }
            }
        }
        .onAppear { runCinematicSequence() }
    }
    
    func runCinematicSequence() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 2.5)) { brightnessDim = 0.6 }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation(.none) { timeString = "2:14" }
                HapticManager.shared.playGlitchHaptic()
                withAnimation(.easeInOut(duration: 0.1)) { glitchOpacity = 0.4 }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    glitchOpacity = 0.0
                    withAnimation(.easeOut(duration: 0.6)) { showGhostNotifications = false }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                            showAlexNotification = true
                        }
                        HapticManager.shared.playGlitchHaptic()
                        canUnlock = true
                        onAppearAction()
                    }
                }
            }
        }
    }
}

// MARK: Notification Chip (Lock Screen)

struct NotificationChip: View {
    let title: String
    let message: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption2).fontWeight(.bold).foregroundColor(.gray)
                Text(message).font(.subheadline).foregroundColor(.white)
            }
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Color.white.opacity(0.15))
        .cornerRadius(14)
    }
}
