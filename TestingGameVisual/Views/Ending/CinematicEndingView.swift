import SwiftUI
import UIKit

// MARK: - CINEMATIC ENDING VIEW

struct CinematicEndingView: View {
    @ObservedObject var gameManager: GameManager
    let onPlayAgain: () -> Void
    let onReturnToMenu: () -> Void
    let onShare: (() -> Void)?
    
    @State private var phase: EndingPhase = .blackout
    @State private var showShareSheet = false
    @State private var shareImage: UIImage? = nil
    
    enum EndingPhase {
        case blackout, titleReveal, glitchIn, profileReveal, statsReveal, buttonsReveal
    }
    
    private var profile: (title: String, description: String, color: Color) {
        gameManager.psychologicalProfile
    }

    private var stats: (trust: Int, denial: Int, avoidance: Int) {
        (trust: gameManager.trustCount, denial: gameManager.denialCount, avoidance: gameManager.avoidanceCount)
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            scanlineBackground
            
            if phase == .titleReveal {
                Text("E N D I N G")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .tracking(10)
                    .transition(.opacity)
            }
            
            if phase != .blackout && phase != .titleReveal {
                VStack(spacing: 0) {
                    Spacer()
                    
                    if phase != .glitchIn {
                        VStack(spacing: 6) {
                            Text("SESSION TERMINATED")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundColor(.gray)
                                .tracking(4)
                            Text("OCT 18, 2019  ·  02:14 AM")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.gray.opacity(0.5))
                        }
                        .transition(.opacity)
                        .padding(.bottom, 24)
                    }
                    
                    if phase == .profileReveal || phase == .statsReveal || phase == .buttonsReveal {
                        profileCard
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.92)),
                                removal: .opacity
                            ))
                            .padding(.horizontal, 28)
                    }
                    
                    if phase == .statsReveal || phase == .buttonsReveal {
                        statsRow
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .padding(.top, 20)
                            .padding(.horizontal, 28)
                    }
                    
                    Spacer()
                    
                    if phase == .buttonsReveal {
                        buttonsSection
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .padding(.horizontal, 28)
                            .padding(.bottom, 50)
                    }
                }
            }
            
            if phase == .glitchIn {
                Color.white.opacity(0.08).ignoresSafeArea()
                    .transition(.opacity)
            }
        }
        .onAppear { runEndingAnimation() }
        .sheet(isPresented: $showShareSheet) {
            if let img = shareImage {
                ActivityViewRepresentable(items: [img])
            }
        }
    }
    
    private var scanlineBackground: some View {
        VStack(spacing: 0) {
            ForEach(0..<60, id: \.self) { i in
                Color.white.opacity(i % 3 == 0 ? 0.018 : 0).frame(height: 2)
                Color.clear.frame(height: 12)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
    
    private var profileCard: some View {
        VStack(spacing: 18) {
            profile.color.opacity(0.8).frame(height: 2).padding(.horizontal, -24)
            
            ZStack {
                Circle()
                    .fill(profile.color.opacity(0.12))
                    .frame(width: 64, height: 64)
                Image(systemName: profileIcon)
                    .font(.system(size: 28))
                    .foregroundColor(profile.color)
            }
            
            Text(profile.title)
                .font(.system(size: 34, weight: .black))
                .foregroundColor(profile.color)
                .multilineTextAlignment(.center)
            
            profile.color.opacity(0.3).frame(height: 1)
            
            Text(profile.description)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(profile.color.opacity(0.4), lineWidth: 1.5))
        )
        .shadow(color: profile.color.opacity(0.15), radius: 20)
    }
    
    private var profileIcon: String {
        switch profile.title {
        case "THE SAVIOR":   return "heart.fill"
        case "THE DENIER":   return "xmark.shield.fill"
        case "THE COWARD":   return "eye.slash.fill"
        default:             return "questionmark.circle.fill"
        }
    }
    
    private var statsRow: some View {
        HStack(spacing: 0) {
            EndingStatBlock(value: "\(stats.trust)",              label: "TRUST",  color: .blue)
            dividerLine
            EndingStatBlock(value: "\(stats.denial)",             label: "DENIAL", color: .red)
            dividerLine
            EndingStatBlock(value: "\(stats.avoidance)",          label: "AVOID",  color: .gray)
            dividerLine
            EndingStatBlock(value: "\(abs(gameManager.denialScore))", label: "PSYCH",  color: profile.color)
        }
        .background(Color.white.opacity(0.04))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
    
    private var dividerLine: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 1)
            .padding(.vertical, 12)
    }
    
    private var buttonsSection: some View {
        VStack(spacing: 12) {
            Button { generateShareAndPresent() } label: {
                Label("Share Ending", systemImage: "square.and.arrow.up")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(profile.color)
                    .cornerRadius(14)
            }
            
            Button {
                HapticManager.shared.playTypeHaptic()
                onPlayAgain()
            } label: {
                Text("Play Again")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.2), lineWidth: 1))
            }
            
            Button {
                HapticManager.shared.playTypeHaptic()
                onReturnToMenu()
            } label: {
                Text("Main Menu")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            .padding(.top, 4)
        }
    }
    
    private func runEndingAnimation() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeIn(duration: 1.5)) { phase = .titleReveal }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            withAnimation(.easeOut(duration: 0.8)) { phase = .blackout }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            withAnimation(.easeIn(duration: 0.3)) { phase = .glitchIn }
            HapticManager.shared.playGlitchHaptic()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.7) {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.75)) { phase = .profileReveal }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.9) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { phase = .statsReveal }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 7.7) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { phase = .buttonsReveal }

            // Unlock current ending and increment clear count
            let currentTitle = profile.title
            if !AppSettings.shared.unlockedEndings.contains(currentTitle) {
                AppSettings.shared.unlockedEndings.append(currentTitle)
            }
            AppSettings.shared.totalClears += 1
        }
    }
    
    private func generateShareAndPresent() {
        if #available(iOS 16.0, *) {
            shareImage = renderShareCard(profile: profile)
        }
        showShareSheet = true
    }
}

private struct EndingStatBlock: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .black, design: .monospaced))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundColor(.gray)
                .tracking(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }
}
