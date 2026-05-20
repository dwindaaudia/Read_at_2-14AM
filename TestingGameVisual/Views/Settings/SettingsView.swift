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

                    // ── Header ───────────────────────────────────────────────
                    Text("SETTINGS")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                        .tracking(5)
                        .padding(.top, 50)
                        .frame(maxWidth: .infinity, alignment: .center)

                    // ── Audio Section ────────────────────────────────────────
                    SettingsSection(title: "AUDIO") {
                        VStack(spacing: 20) {
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
                    }

                    // ── Experience Section ───────────────────────────────────
                    SettingsSection(title: "EXPERIENCE") {
                        VStack(spacing: 16) {
                            Toggle(isOn: $settings.hapticsEnabled) {
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
                                }
                            }
                            .tint(.blue)

                            Toggle(isOn: $settings.debugBarVisible) {
                                HStack(spacing: 10) {
                                    Image(systemName: "ladybug")
                                        .foregroundColor(.gray)
                                        .frame(width: 22)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Developer Debug Bar")
                                            .font(.subheadline)
                                            .foregroundColor(.white)
                                        Text("Shows denial score, act, scene, model mode")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            .tint(.orange)
                        }
                    }

                    // ── Data Section ─────────────────────────────────────────
                    SettingsSection(title: "DATA") {
                        VStack(spacing: 12) {
                            // Reset tutorial
                            Button {
                                settings.resetProgress()
                                HapticManager.shared.playTypeHaptic()
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.counterclockwise")
                                        .foregroundColor(.orange)
                                    Text("Reset Tutorial")
                                        .foregroundColor(.orange)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 13)
                                .background(Color.orange.opacity(0.08))
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.2), lineWidth: 1))
                            }

                            // Reset all progress
                            Button {
                                showResetConfirm = true
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
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.red.opacity(0.2), lineWidth: 1))
                            }
                            .confirmationDialog(
                                "This will erase all settings and tutorial progress.",
                                isPresented: $showResetConfirm,
                                titleVisibility: .visible
                            ) {
                                Button("Reset Everything", role: .destructive) {
                                    settings.resetProgress()
                                    settings.musicVolume = 0.5
                                    settings.sfxVolume = 0.8
                                    settings.hapticsEnabled = true
                                    onResetAll?()
                                    HapticManager.shared.playGlitchHaptic()
                                    dismiss()
                                }
                                Button("Cancel", role: .cancel) {}
                            }
                        }
                    }

                    // ── Version ──────────────────────────────────────────────
                    Text("READ AT 2:14 AM  ·  v1.0")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.gray.opacity(0.35))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 8)

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
            }
        }
        .overlay(
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray)
                    .padding(16)
                    .background(Color.white.opacity(0.08), in: Circle())
            }
            .padding(16),
            alignment: .topTrailing
        )
    }
}

// ── Settings Section Container ───────────────────────────────────────────────

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
                .tracking(3)
            content
        }
    }
}

// ── Volume Slider ────────────────────────────────────────────────────────────

private struct SettingsSlider: View {
    let label: String
    let icon: String
    @Binding var value: Float

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.gray)
                    .frame(width: 20)
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.white)
                Spacer()
                Text("\(Int(value * 100))%")
                    .font(.caption.monospaced())
                    .foregroundColor(.gray)
            }
            Slider(value: $value, in: 0...1)
                .tint(.white.opacity(0.7))
        }
    }
}
