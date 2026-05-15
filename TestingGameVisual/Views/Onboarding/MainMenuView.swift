import SwiftUI

// MARK: - MAIN MENU

struct MainMenuView: View {

    let onNewGame: () -> Void
    let onContinue: () -> Void

    @State private var titleOpacity: Double   = 0
    @State private var buttonsOpacity: Double = 0
    @State private var glitchOffsetX: CGFloat = 0
    @State private var showSettings  = false
    @State private var showCredits   = false
    @State private var showHowToPlay = false
    @State private var showAchievements = false

    // Random glitch timer
    @State private var glitchTimer: Timer?

    var body: some View {
        ZStack {
            // ── Background ─────────────────────────────────────────────────
            Image("ls_wallpaper")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
                .opacity(0.5)

            // Subtle scanlines overlay
            VStack(spacing: 0) {
                ForEach(0..<50, id: \.self) { i in
                    Color.white
                        .opacity(i % 4 == 0 ? 0.025 : 0)
                        .frame(height: 2)
                    Color.clear.frame(height: 14)
                }
            }
            .allowsHitTesting(false)

            // ── Content ────────────────────────────────────────────────────
            VStack(spacing: 0) {
                HStack {
                    Text("Friday 8")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.trailing, 18)
                    
                    // Glitch Title
                    ZStack {
                        // Red chromatic ghost
                        Text("2:14")
                            .font(.system(size: 56, weight: .black))
                            .foregroundColor(.red.opacity(0.55))
                            .offset(x: glitchOffsetX + 3, y: 2)
                        
                        // Cyan chromatic ghost
                        Text("2:14")
                            .font(.system(size: 56, weight: .black))
                            .foregroundColor(.cyan.opacity(0.35))
                            .offset(x: -glitchOffsetX - 2, y: -2)
                        
                        // Main white title
                        Text("2:14")
                            .font(.system(size: 56, weight: .black))
                            .foregroundColor(.white)
                    }
                    .opacity(titleOpacity)
                    
                    Text("Chapter 1")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.leading, 18)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 100)
                
                Spacer()
                
                // ── Scroll View for Alex Notifications ───────────────────
                VStack {
                    HStack {
                        Text("Notifications")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text("Clear All")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 10) {
                            // Contoh pemanggilan manual
                            AlexNotificationCard(message: "Are you awake?", time: "02:14 AM")
                            
                            AlexNotificationCard(message: "I saw it behind you.", time: "02:14 AM")
                            
                            AlexNotificationCard(message: "Run.", time: "02:14 AM")
                            
                            // Atau jika menggunakan data array:
                            /*
                             ForEach(notifications) { notification in
                             AlexNotificationCard(message: notification.text, time: notification.time)
                             }
                             */
                        }
                        .padding(.top, 20)
                    }
                    .frame(maxHeight: 350)
                    .mask(
                        LinearGradient(gradient: Gradient(colors: [.clear, .black, .black, .clear]), startPoint: .top, endPoint: .bottom)
                    )
                }
                
                Text("Click the Notification to Play the Game")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.bottom, 50)

                // ── Menu Buttons ───────────────────────────────────────────
                HStack() {
                    
                    // 1. SETTINGS
                    Button(action: {
                        HapticManager.shared.playTypeHaptic()
                        showSettings = true
                    }) {
                        VStack(spacing: 10) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                            Text("SETTINGS")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 40)
                    
                    // 2. CHAT
                    // Logika Tukar Tombol: NEW CHAT vs CONTINUE CHAT
                        if GameSaveManager.shared.hasSave {
                            // Tampilkan ini jika SUDAH PERNAH main
                            Button(action: {
                                HapticManager.shared.playTypeHaptic()
                                withAnimation(.easeIn(duration: 0.3)) { buttonsOpacity = 0 }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { onContinue() }
                            }) {
                                VStack(spacing: 10) {
                                    Image(systemName: "message.fill")
                                        .font(.system(size: 30))
                                        .foregroundColor(.white) // Beri warna beda agar pemain sadar ini save-an
                                    Text("CHAT")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                        } else {
                            // Tampilkan ini jika PLAYER BARU
                            Button(action: {
                                HapticManager.shared.playTypeHaptic()
                                withAnimation(.easeIn(duration: 0.3)) { buttonsOpacity = 0 }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { onNewGame() }
                            }) {
                                VStack(spacing: 10) {
                                    Image(systemName: "message.badge.fill") // Ikon berbeda sedikit untuk "New"
                                        .font(.system(size: 30))
                                        .foregroundColor(.white)
                                    Text("CHAT")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                    
                    // 3. EVIDENCES FILE
                    Button(action: {
                        EvidenceBoardButton()
                    }) {
                        VStack(spacing: 10) {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                            Text("FILES")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 40)
                }
//                .opacity(buttonsOpacity)
                .tint(Color.red.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .bottom)
                .padding(.bottom, 70)
            }
        }
        .onAppear {
            withAnimation(.easeIn(duration: 1.4))               { titleOpacity   = 1.0 }
            withAnimation(.easeIn(duration: 1.0).delay(0.9))   { buttonsOpacity = 1.0 }
            startGlitchLoop()
        }
        .onDisappear { glitchTimer?.invalidate() }
        .sheet(isPresented: $showSettings)  { SettingsView() }
    }

    // Irregular glitch bursts on the title
    private func startGlitchLoop() {
        scheduleNextGlitch()
    }

    private func scheduleNextGlitch() {
        let waitTime = Double.random(in: 3.5...8.0)
        glitchTimer = Timer.scheduledTimer(withTimeInterval: waitTime, repeats: false) { _ in
            runGlitchBurst()
            scheduleNextGlitch()
        }
    }

    private func runGlitchBurst() {
        let moves: [(CGFloat, Double)] = [(10, 0.05), (0, 0.05), (-8, 0.04), (0, 0.05), (6, 0.03), (0, 0)]
        var t = 0.0
        for (offset, dur) in moves {
            DispatchQueue.main.asyncAfter(deadline: .now() + t) {
                withAnimation(.linear(duration: 0.04)) { glitchOffsetX = offset }
            }
            t += dur
        }
        HapticManager.shared.playTypeHaptic()
    }
}
