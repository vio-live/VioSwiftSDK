import SwiftUI

/// Chat simple para vista de casting - ancho fijo, sin GeometryReader
struct CastingChatPanel: View {
    @ObservedObject var chatManager: ChatManager
    @State private var messageText = ""
    @State private var isExpanded = false
    
    private let collapsedHeight: CGFloat = 50
    private let expandedHeight: CGFloat = 250
    
    var body: some View {
        VStack(spacing: 0) {
            // Header / Drag handle
            chatHeader
            
            // Chat messages (solo cuando está expandido)
            if isExpanded {
                chatMessages
            }
        }
        .frame(width: 400) // ANCHO FIJO
        .frame(height: isExpanded ? expandedHeight : collapsedHeight)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.7))
                .background(.ultraThinMaterial)
        )
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
        .animation(.spring(response: 0.3), value: isExpanded)
    }
    
    // MARK: - Chat Header
    
    private var chatHeader: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3)) {
                isExpanded.toggle()
            }
        }) {
            HStack {
                Image(systemName: "message.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                
                Text("LIVE CHAT")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                
                Text("(\(chatManager.messages.count))")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
                
                Spacer()
                
                Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(height: collapsedHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Chat Messages
    
    private var chatMessages: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.white.opacity(0.2))
            
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(chatManager.messages.suffix(15)) { message in
                            chatMessageRow(message)
                                .id(message.id)
                        }
                    }
                    .padding(16)
                }
                .frame(height: expandedHeight - collapsedHeight - 60)
                .onChange(of: chatManager.messages.count) { _ in
                    if let lastMessage = chatManager.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.2))
            
            // Input bar
            chatInputBar
        }
    }
    
    private func chatMessageRow(_ message: ChatMessage) -> some View {
        HStack(alignment: .top, spacing: 10) {
            // Avatar
            ZStack {
                Circle()
                    .fill(message.usernameColor.opacity(0.3))
                    .frame(width: 28, height: 28)
                
                Text(message.username.prefix(1).uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(message.usernameColor)
            }
            
            // Message content
            VStack(alignment: .leading, spacing: 3) {
                Text(message.username)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(message.usernameColor)
                
                Text(message.text)
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 0)
        }
    }
    
    // MARK: - Input Bar
    
    private var chatInputBar: some View {
        HStack(spacing: 10) {
            TextField("Escribe un mensaje...", text: $messageText)
                .font(.system(size: 14))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.15))
                )
            
            Button(action: sendMessage) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 16))
                    .foregroundColor(messageText.isEmpty ? .white.opacity(0.4) : TV2Theme.Colors.primary)
                    .frame(width: 38, height: 38)
                    .background(
                        Circle()
                            .fill(messageText.isEmpty ? Color.white.opacity(0.1) : TV2Theme.Colors.primary.opacity(0.2))
                    )
            }
            .disabled(messageText.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(height: 60)
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let newMessage = ChatMessage(
            username: "Angelo",
            text: messageText,
            usernameColor: TV2Theme.Colors.primary,
            likes: 0,
            timestamp: Date()
        )
        
        chatManager.addMessage(newMessage)
        messageText = ""
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack {
            Spacer()
            CastingChatPanel(chatManager: ChatManager())
                .padding()
        }
    }
}

