import SwiftUI

// MARK: - Locked archive (chat bubble + Files screen)

struct LockedFileAttachmentView: View {
    let fileID: String
    let isFromMe: Bool
    var bubbleColor: Color
    var maxWidth: CGFloat = 300

    @State private var showDecryptTheatre = false

    private var displayName: String {
        let trimmed = fileID.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "HIDDEN-FILE.zip" : trimmed
    }

    var body: some View {
        Button {
            HapticManager.shared.playTypeHaptic()
            showDecryptTheatre = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "lock.doc.fill")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.9))
                Text(displayName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(14)
            .frame(maxWidth: maxWidth, alignment: isFromMe ? .trailing : .leading)
            .background(bubbleColor)
            .overlay(Rectangle().stroke(Color.white.opacity(0.08), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .fullScreenCover(isPresented: $showDecryptTheatre) {
            CorruptedDecryptTheatreView()
        }
    }
}

// MARK: - Corrupted decrypt theatre (post–story beat)

struct CorruptedDecryptTheatreView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var progress: Int = 0
    @State private var phase: Phase = .running
    @State private var glitchOffset: CGFloat = 0
    @State private var timer: Timer?

    private enum Phase {
        case running, failed
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 28) {
                Text("HIDDEN-FILE.zip")
                    .font(.helvetica(12, weight: .bold))
                    .foregroundColor(.red.opacity(0.9))
                    .offset(x: glitchOffset)

                if phase == .running {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("EXTRACTING FRAGMENTS…")
                            .font(.helvetica(10, weight: .semibold))
                            .foregroundColor(.gray)
                        ProgressView(value: Double(progress), total: 100)
                            .tint(.red)
                        Text("\(progress)%")
                            .font(.helvetica(28, weight: .black))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: 280)
                } else {
                    VStack(spacing: 14) {
                        Text("DECRYPT FAILED")
                            .font(.helvetica(20, weight: .black))
                            .foregroundColor(.red)
                        Text("checksum mismatch · sector 0x214 corrupted · payload unreadable")
                            .font(.helvetica(11))
                            .foregroundColor(.white.opacity(0.55))
                            .multilineTextAlignment(.center)
                        Text("The file knows you opened it anyway.")
                            .font(.helvetica(14, weight: .medium))
                            .foregroundColor(.white.opacity(0.72))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    .padding(.top, 8)
                }

                if phase == .failed {
                    Button("CLOSE") {
                        dismiss()
                    }
                    .font(.helvetica(15, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .clipShape(Rectangle())
                    .padding(.top, 12)
                }
            }
            .padding(32)
        }
        .onAppear { startRun() }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }

    private func startRun() {
        timer?.invalidate()
        progress = 0
        phase = .running
        HapticManager.shared.playGlitchHaptic()
        timer = Timer.scheduledTimer(withTimeInterval: 0.028, repeats: true) { t in
            if progress < 100 {
                progress += 1
                if progress % 7 == 0 {
                    glitchOffset = CGFloat.random(in: -3...3)
                }
                if progress == 37 || progress == 68 {
                    HapticManager.shared.playTypeHaptic()
                }
            } else {
                t.invalidate()
                timer = nil
                glitchOffset = 0
                withAnimation(.easeOut(duration: 0.25)) {
                    phase = .failed
                }
                HapticManager.shared.playGlitchHaptic()
            }
        }
    }
}
