import SwiftUI
import VioCore
import VioLiveShow
import VioDesignSystem

/// Reusable Live Chat component for LiveShow overlays
public struct RLiveChatComponent: View {
    
    // MARK: - Properties
    @ObservedObject private var chatManager: LiveChatManager
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var messageText = ""
    @State private var showChat = true
    @State private var userNameInput = ""
    @State private var showUserNameInput = false
    
    // Colors based on theme
    private var adaptiveColors: AdaptiveColors {
        VioColors.adaptive(for: colorScheme)
    }
    
    public init(channel: String? = nil, role: String = "USER", chatManager: LiveChatManager? = nil) {
        self.chatManager = chatManager ?? LiveChatManager.shared
        if let channel = channel {
            self.chatManager.configure(channel: channel, role: role)
        }
    }
    
    // MARK: - Body
    public var body: some View {
        VStack(spacing: 0) {
            // Pinned message (shown at top when available)
            if let pinnedMessage = chatManager.pinnedMessage {
                pinnedMessageView(pinnedMessage)
            }
            
            if showChat {
                // Chat messages with fading gradient background (no header)
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: VioSpacing.xs) {
                            ForEach(chatManager.messages) { message in
                                chatMessageView(message: message)
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)
                                    ))
                                    .animation(.easeInOut(duration: 0.3), value: chatManager.messages.count)
                            }
                        }
                        .padding(.horizontal, VioSpacing.md)
                        .padding(.vertical, VioSpacing.sm)
                    }
                    .frame(maxHeight: 120)
                    .background(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.6),
                                Color.black.opacity(0.3),
                                Color.clear
                            ],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .onChange(of: chatManager.messages.count) { _ in
                        // Auto-scroll to last message
                        if let lastMessage = chatManager.messages.last {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            
            // Chat input
            HStack(spacing: VioSpacing.sm) {
                // Toggle chat visibility
                Button(action: { 
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showChat.toggle() 
                    }
                }) {
                    Image(systemName: showChat ? "chevron.down" : "chevron.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                }
                
                // Conditional input: username first, then message
                if chatManager.hasUserName {
                    // Message input
                    TextField("Type a message...", text: $messageText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.body)
                        .foregroundColor(.white)
                        .padding(.horizontal, VioSpacing.md)
                        .padding(.vertical, VioSpacing.sm)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                    
                    // Send button
                    Button(action: sendMessage) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(messageText.isEmpty ? .gray : .white)
                            .frame(width: 32, height: 32)
                            .background(messageText.isEmpty ? Color.gray.opacity(0.3) : adaptiveColors.primary)
                            .clipShape(Circle())
                    }
                    .disabled(messageText.isEmpty)
                } else {
                    // Username input
                    TextField("Enter your name or alias", text: $userNameInput)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.body)
                        .foregroundColor(.white)
                        .padding(.horizontal, VioSpacing.md)
                        .padding(.vertical, VioSpacing.sm)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                    
                    Button(action: setUserName) {
                        Text("Join")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(userNameInput.isEmpty ? .gray : .white)
                            .padding(.horizontal, VioSpacing.md)
                            .padding(.vertical, VioSpacing.sm)
                            .background(userNameInput.isEmpty ? Color.gray.opacity(0.3) : adaptiveColors.primary)
                            .cornerRadius(20)
                    }
                    .disabled(userNameInput.isEmpty)
                }
            }
            .padding(.horizontal, VioSpacing.md)
            .padding(.vertical, VioSpacing.sm)
            .padding(.bottom, 0) // Remove bottom padding to reach edge
            .background(
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.black.opacity(0.7)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .ignoresSafeArea(.container, edges: .bottom) // Extend to screen bottom
        }
    }
    
    // MARK: - Chat Message View
    
    @ViewBuilder
    private func chatMessageView(message: LiveChatMessage) -> some View {
        HStack(alignment: .top, spacing: VioSpacing.xs) {

            // MARK: - Avatar
            avatarView(for: message.user)

            // MARK: - Username + Message
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: VioSpacing.xs) {
                    Text(message.user.username)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(getUsernameColor(for: message))

                    // Role badge
                    if message.user.role != .viewer {
                        roleBadge(for: message.user.role)
                    }
                }

                Text(message.message)
                    .font(.caption)
                    .foregroundColor(.white)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }

    // MARK: - Avatar View
    @ViewBuilder
    private func avatarView(for user: LiveChatUser) -> some View {
        if let avatarUrl = user.avatarUrl, 
           !avatarUrl.isEmpty,
           let url = URL(string: avatarUrl),
           url.scheme != nil {
            // Real avatar URL
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                fallbackAvatar(for: user)
            }
            .frame(width: 16, height: 16)
            .clipShape(Circle())
        } else {
            // Fallback avatar
            fallbackAvatar(for: user)
        }
    }
    
    @ViewBuilder
    private func fallbackAvatar(for user: LiveChatUser) -> some View {
        Circle()
            .fill(avatarColor(for: user))
            .overlay(
                Text(avatarInitial(for: user))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            )
            .frame(width: 16, height: 16)
    }
    
    private func avatarColor(for user: LiveChatUser) -> Color {
        // Use different colors based on user role
        switch user.role {
        case .streamer:
            return .purple
        case .admin:
            return .red
        case .moderator:
            return .yellow
        case .vip:
            return .orange
        case .subscriber:
            return .blue
        case .viewer:
            // Generate consistent color based on username
            let colors: [Color] = [.green, .pink, .teal, .indigo, .mint]
            let hash = abs(user.username.hashValue)
            return colors[hash % colors.count]
        }
    }
    
    @ViewBuilder
    private func roleBadge(for role: ChatUserRole) -> some View {
        Text(role.displayName)
            .font(.caption2.weight(.bold))
            .foregroundColor(roleTextColor(for: role))
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(roleBackgroundColor(for: role))
            .cornerRadius(4)
    }
    
    private func roleTextColor(for role: ChatUserRole) -> Color {
        switch role {
        case .streamer, .admin:
            return .white
        case .moderator, .vip:
            return .black
        case .subscriber:
            return .white
        case .viewer:
            return .white
        }
    }
    
    private func roleBackgroundColor(for role: ChatUserRole) -> Color {
        switch role {
        case .streamer:
            return .purple
        case .admin:
            return .red
        case .moderator:
            return .yellow
        case .vip:
            return .orange
        case .subscriber:
            return .blue
        case .viewer:
            return .gray
        }
    }
    
    private func avatarInitial(for user: LiveChatUser) -> String {
        // Clean username and get first character
        let cleanUsername = user.username
            .replacingOccurrences(of: "@", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if cleanUsername.isEmpty {
            return "?"
        }
        
        return String(cleanUsername.prefix(1)).uppercased()
    }
    
    // MARK: - Utilidad para color estable por usuario (legacy)
    private func colorForUsername(_ username: String) -> Color {
        let colors: [Color] = [.blue, .green, .orange, .pink, .purple, .red, .teal, .yellow]
        let hash = abs(username.hashValue)
        return colors[hash % colors.count]
    }

    // MARK: - Helper Methods
    
    private func getUsernameColor(for message: LiveChatMessage) -> Color {
        if message.isStreamerMessage {
            return Color.red // Streamer messages in red
        } else if message.user.isModerator {
            return Color.yellow // Moderator messages in yellow
        } else {
            return Color.white.opacity(0.9) // Regular users (no verified badge)
        }
    }
    
    private func setUserName() {
        guard !userNameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        chatManager.setUserName(userNameInput)
        userNameInput = ""
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        chatManager.sendMessage(messageText)
        messageText = ""
    }
    
    // MARK: - Pinned Message View
    
    private func pinnedMessageView(_ message: LiveChatMessage) -> some View {
        VStack(spacing: VioSpacing.xs) {
            HStack(spacing: VioSpacing.sm) {
                // Pin icon
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundColor(.yellow)
                
                // Username
                Text(message.user.username)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.yellow)
                
                Spacer()
            }
            
            // Message text
            HStack {
                Text(message.message)
                    .font(.caption)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                
                Spacer()
            }
        }
        .padding(.horizontal, VioSpacing.md)
        .padding(.vertical, VioSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.yellow.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, VioSpacing.md)
        .padding(.vertical, VioSpacing.xs)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack {
            Spacer()
            RLiveChatComponent()
        }
    }
}
