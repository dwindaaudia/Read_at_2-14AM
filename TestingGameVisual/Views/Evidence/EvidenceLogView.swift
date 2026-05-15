import SwiftUI

// MARK: - EVIDENCE LOG / ARCHIVE

struct EvidenceLogView: View {
    @ObservedObject var gameManager: GameManager
    @Environment(\.dismiss) var dismiss
    
    private var evidenceMessages: [Message] {
        gameManager.messages.filter {
            switch $0.type {
            case .image, .voiceNote, .lockedFile: return true
            default: return false
            }
        }
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("EVIDENCE LOG")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                        .tracking(4)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.gray)
                            .padding(12)
                            .background(Color.white.opacity(0.08), in: Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 16)
                
                if evidenceMessages.isEmpty {
                    Spacer()
                    Text("No evidence collected yet.")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.gray.opacity(0.5))
                    Spacer()
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(evidenceMessages) { msg in
                                EvidenceCard(message: msg)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 32)
                    }
                }
            }
        }
    }
}

private struct EvidenceCard: View {
    let message: Message
    
    var body: some View {
        Group {
            switch message.type {
            case .image(let name):
                ImageEvidenceCard(assetName: name, time: message.time)
            case .voiceNote(let filename):
                VoiceEvidenceCard(filename: filename, time: message.time)
            case .lockedFile(let id):
                LockedEvidenceCard(fileID: id, time: message.time)
            default:
                EmptyView()
            }
        }
    }
}

private struct ImageEvidenceCard: View {
    let assetName: String
    let time: String
    @State private var expanded = false
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image(assetName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 160)
                .clipped()
                .cornerRadius(10)
            
            LinearGradient(colors: [.clear, .black.opacity(0.7)],
                           startPoint: .center, endPoint: .bottom)
            .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 2) {
                Image(systemName: "photo.fill")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
                Text(time)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(8)
        }
        .onTapGesture { expanded = true }
        .fullScreenCover(isPresented: $expanded) {
            ImageLightboxView(assetName: assetName, caption: "")
        }
    }
}

private struct VoiceEvidenceCard: View {
    let filename: String
    let time: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "waveform")
                .font(.system(size: 28))
                .foregroundColor(.red.opacity(0.7))
            
            Text(filename.replacingOccurrences(of: ".mp3", with: ""))
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
                .lineLimit(1)
            
            Text(time)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.gray)
            
            VoiceNotePlayerBubble(filename: filename, isFromMe: false)
                .scaleEffect(0.82, anchor: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, -8)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.red.opacity(0.2), lineWidth: 1))
    }
}

private struct LockedEvidenceCard: View {
    let fileID: String
    let time: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "lock.doc.fill")
                .font(.system(size: 28))
                .foregroundColor(.red.opacity(0.7))
            
            Text(fileID)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
                .lineLimit(2)
            
            Text(time)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.gray)
            
            Text("ENCRYPTED")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.red)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color.red.opacity(0.12))
                .cornerRadius(4)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.red.opacity(0.2), lineWidth: 1))
    }
}
