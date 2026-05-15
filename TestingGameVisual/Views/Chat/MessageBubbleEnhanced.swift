import SwiftUI

// MARK: - MESSAGE BUBBLE ENHANCED

struct MessageBubbleEnhanced: View {
    let message: Message
    var useTypewriter: Bool = false
    
    var body: some View {
        HStack {
            if message.isFromMe { Spacer() }
            
            VStack(alignment: message.isFromMe ? .trailing : .leading, spacing: 4) {
                switch message.type {
                    
                case .systemAlert:
                    Text(message.text)
                        .font(.caption.monospaced())
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .foregroundColor(.red).background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red, lineWidth: 1))
                    
                case .text:
                    if useTypewriter && !message.isFromMe {
                        TypewriterText(fullText: message.text, speed: 0.025)
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .foregroundColor(.primary)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(ChatBubbleShape(isFromMe: false))
                    } else {
                        Text(message.text)
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .foregroundColor(message.isFromMe ? .white : .primary)
                            .background(message.isFromMe ? Color.red.opacity(0.45) : Color(UIColor.secondarySystemBackground))
                            .clipShape(ChatBubbleShape(isFromMe: message.isFromMe))
                    }
                    
                case .image(let assetName):
                    ImageLightboxView(assetName: assetName, caption: message.text)
                    
                case .voiceNote(let id):
                    VoiceNotePlayerBubble(filename: id, isFromMe: message.isFromMe)
                    
                case .lockedFile(let id):
                    HStack(spacing: 12) {
                        Image(systemName: "lock.doc.fill").font(.title2).foregroundColor(.red)
                        VStack(alignment: .leading) {
                            Text("Hidden File").font(.subheadline).fontWeight(.bold)
                            Text(id).font(.caption).foregroundColor(.gray)
                        }
                    }
                    .padding(14)
                    .background(Color(white: 0.15)).foregroundColor(.white)
                    .clipShape(ChatBubbleShape(isFromMe: message.isFromMe))
                    .overlay(ChatBubbleShape(isFromMe: message.isFromMe).stroke(Color.red.opacity(0.5), lineWidth: 1))
                }
                
                if message.type != .systemAlert {
                    HStack(spacing: 4) {
                        Text(message.time)
                        if message.isFromMe {
                            Image(systemName: message.isRead ? "checkmark.message.fill" : "checkmark.message")
                                .foregroundColor(message.isRead ? .red.opacity(0.45) : .gray)
                        }
                    }
                    .font(.caption2).foregroundColor(.white.opacity(0.7))
                    .padding(message.isFromMe ? .trailing : .leading, 8)
                }
            }
            
            if !message.isFromMe { Spacer() }
        }
        .padding(.horizontal)
    }
}
