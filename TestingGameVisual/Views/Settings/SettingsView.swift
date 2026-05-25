import SwiftUI

// MARK: - SETTINGS SHEET

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var settings = AppSettings.shared
    @State private var showResetConfirm = false
    
    /// Provided by the root so the Reset action can also wipe save / evidence / game state.
    var onResetAll: (() -> Void)? = nil
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    
                    Text("SETTINGS")
                        .font(.helvetica(11, weight: .bold))
                        .foregroundColor(.gray)
                        .tracking(5)
                        .padding(.top, 50)
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    VStack(spacing: 24) {
                        SettingsSlider(
                            label: "Music Volume",
                            icon: "music.note",
                            value: $settings.musicVolume
                        )
                        SettingsSlider(
                            label: "SFX & Ambience",
                            icon: "waveform",
                            value: $settings.sfxVolume
                        )
                    }
                    
                    VStack(spacing: 16) {
                        HStack(spacing: 10) {
                            Image(systemName: "iphone.radiowaves.left.and.right")
                                .foregroundColor(.gray)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Haptic Feedback")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                Text("Heartbeat, glitches & jump events")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            CustomToggle(isOn: $settings.hapticsEnabled)
                        }
                    }
                    
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showResetConfirm = true
                        }
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                            Text("Reset All Game Data")
                                .foregroundColor(.red)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 13)
                        .background(Color.red.opacity(0.08))
                        .overlay(Rectangle().stroke(Color.red.opacity(0.3), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    
                    Text("READ AT 2:14 AM  ·  v1.0")
                        .font(.helvetica(10))
                        .foregroundColor(.gray.opacity(0.35))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 8)
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
            }
            
            // Tombol Dismiss
            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.gray)
                            .padding(16)
                    }
                    .padding(16)
                }
                Spacer()
            }
            
            if showResetConfirm {
                ZStack {
                    Color.black.opacity(0.85)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) { showResetConfirm = false }
                        }
                    
                    VStack(spacing: 24) {
                        VStack(spacing: 8) {
                            Text("ERASE ALL DATA?")
                                .font(.helvetica(16, weight: .bold))
                                .foregroundColor(.red)
                                .tracking(1.5)
                            
                            Text("This will wipe all settings, evidence, and tutorial progress. You cannot undo this.")
                                .font(.helvetica(13))
                                .foregroundColor(.white.opacity(0.65))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 12)
                        }
                        
                        VStack(spacing: 12) {
                            Button {
                                settings.resetProgress()
                                settings.musicVolume = 0.5
                                settings.sfxVolume = 0.8
                                settings.hapticsEnabled = true
                                onResetAll?()
                                HapticManager.shared.playGlitchHaptic()
                                showResetConfirm = false
                                dismiss()
                            } label: {
                                Text("RESET EVERYTHING")
                                    .font(.helvetica(13, weight: .bold))
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.red)
                            }
                            
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showResetConfirm = false
                                }
                            } label: {
                                Text("CANCEL")
                                    .font(.helvetica(13, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.white.opacity(0.1))
                                    .overlay(Rectangle().stroke(Color.white.opacity(0.3), lineWidth: 1))
                            }
                        }
                    }
                    .padding(24)
                    .background(Color(red: 0.08, green: 0.08, blue: 0.08)) // Dark Maroon/Grayish
                    .overlay(Rectangle().stroke(Color.red.opacity(0.4), lineWidth: 1))
                    .padding(32)
                }
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .simultaneousGesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .global)
                .onEnded { value in
                    let horizontalSwipe = value.translation.width
                    let predictedHorizontal = value.predictedEndTranslation.width
                    let verticalSwipe = abs(value.translation.height)
                    
                    if (horizontalSwipe > 50 || predictedHorizontal > 150) && verticalSwipe < 60 {
                        HapticManager.shared.playTypeHaptic()
                        dismiss()
                    }
                }
        )
    }
}

// MARK: - CUSTOM COMPONENTS

// ── Custom Volume Slider ─────────────────────────────────────────────────────

private struct SettingsSlider: View {
    let label: String
    let icon: String
    @Binding var value: Float
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.gray)
                    .frame(width: 20)
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.white)
                Spacer()
                Text("\(Int(value * 100))%")
                    .font(.helvetica(11))
                    .foregroundColor(.gray)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 4)
                    
                    Rectangle()
                        .fill(Color.white.opacity(0.85))
                        .frame(width: max(0, geometry.size.width * CGFloat(value)), height: 4)
                    
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 8, height: 16)
                        .offset(x: max(0, min(geometry.size.width - 8, geometry.size.width * CGFloat(value) - 4)))
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            let percentage = min(max(0, gesture.location.x / geometry.size.width), 1)
                            value = Float(percentage)
                        }
                )
            }
            .frame(height: 16)
        }
    }
}

// ── Custom Toggle Switch ─────────────────────────────────────────────────────

private struct CustomToggle: View {
    @Binding var isOn: Bool
    
    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Rectangle()
                .fill(Color.black.opacity(0.5))
                .overlay(Rectangle().stroke(Color.white.opacity(0.3), lineWidth: 1))
                .frame(width: 44, height: 22)
            
            Rectangle()
                .fill(isOn ? Color.white : Color.gray.opacity(0.6))
                .frame(width: 22, height: 22)
        }
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isOn.toggle()
            }
            HapticManager.shared.playTypeHaptic()
        }
    }
}
