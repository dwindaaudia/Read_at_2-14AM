import SwiftUI

// Full message thread for the unknown contact
struct UnknownContactView: View {
    @ObservedObject private var manager = UnknownContactManager.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                ZStack {
                    Color(white: 0.06).ignoresSafeArea(edges: .top)
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.left").foregroundColor(.white)
                        }
                        Spacer()
                        VStack(spacing: 2) {
                            Text("+62 000-0214")
                                .font(.headline).foregroundColor(.white)
                            Text("Tidak Dikenal")
                                .font(.caption).foregroundColor(.red)
                        }
                        Spacer()
                        Image(systemName: "info.circle").foregroundColor(.white.opacity(0.2))
                    }
                    .padding(.horizontal)
                    .padding(.top, 55).padding(.bottom, 12)
                }
                .frame(height: 100)

                if manager.messages.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "questionmark.bubble")
                            .font(.system(size: 40)).foregroundColor(.gray.opacity(0.3))
                        Text("Belum ada pesan.\nTerus bicara dengan Alex.")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(manager.messages) { msg in
                                HStack {
                                    Text(msg.text)
                                        .font(.system(size: 15, design: .monospaced))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 14).padding(.vertical, 10)
                                        .background(Color(white: 0.12))
                                        .clipShape(RoundedRectangle(cornerRadius: 18))
                                    Spacer()
                                }
                                .padding(.horizontal)
                            }

                            Text("[ KONTAK INI TIDAK BISA MENERIMA PESAN ]")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.red.opacity(0.4))
                                .padding(.top, 24)
                                .padding(.bottom, 40)
                        }
                        .padding(.top, 12)
                    }
                }
            }
        }
        .onAppear { manager.markRead() }
    }
}

/// Accesses the Unknown Contact thread. Place in the chat header.
struct UnknownContactButton: View {
    @ObservedObject private var manager = UnknownContactManager.shared
    @State private var showContact = false

    var body: some View {
        Button(action: { showContact = true }) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "questionmark.bubble.fill")
                    .font(.system(size: 18)).foregroundColor(.red.opacity(0.7))
                if manager.hasUnread {
                    Circle().fill(Color.red).frame(width: 9, height: 9).offset(x: 3, y: -3)
                }
            }
        }
        .sheet(isPresented: $showContact) { UnknownContactView() }
    }
}
