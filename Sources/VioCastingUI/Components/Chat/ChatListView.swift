//
//  ChatListView.swift
//  Viaplay
//
//  Organism component: Chat messages list
//

import SwiftUI

struct ChatListView: View {
    let messages: [ChatMessage]
    let viewerCount: Int
    let selectedMinute: Int?
    let compact: Bool
    let canChat: Bool
    let onSendMessage: ((String) -> Void)?
    
    @State private var messageText = ""
    @FocusState private var isInputFocused: Bool
    @State private var keyboardHeight: CGFloat = 0
    
    init(
        messages: [ChatMessage],
        viewerCount: Int = 0,
        selectedMinute: Int? = nil,
        compact: Bool = false,
        canChat: Bool = true,
        onSendMessage: ((String) -> Void)? = nil
    ) {
        self.messages = messages
        self.viewerCount = viewerCount
        self.selectedMinute = selectedMinute
        self.compact = compact
        self.canChat = canChat
        self.onSendMessage = onSendMessage
    }
    
    private var title: String {
        if let minute = selectedMinute {
            return "Chat ved \(minute)'"
        }
        return "Live Chat"
    }
    
    private var isLive: Bool {
        selectedMinute == nil
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages scroll view
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 12) {
                        // Header
                        HStack {
                            Text(title)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            if isLive && viewerCount > 0 {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 8, height: 8)
                                    Text("\(viewerCount)")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        
                        // Messages (oldest to newest - antiguos arriba, nuevos abajo)
                        ForEach(messages) { message in
                            ChatMessageRow(message: message, compact: compact)
                                .padding(.horizontal, 16)
                                .id(message.id)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .bottom).combined(with: .opacity),
                                    removal: .opacity
                                ))
                        }
                        
                        // Invisible anchor at bottom
                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                    .padding(.bottom, canChat && isLive ? (80 + keyboardHeight) : 12)
                }
                .onAppear {
                    // DEMO: Scroll to top on first appear (start of timeline)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        if let firstMessage = messages.first {
                            proxy.scrollTo(firstMessage.id, anchor: .top)
                        }
                    }
                }
                .onChange(of: messages.count) { _ in
                    // DEMO: Don't auto-scroll, let user control scroll position
                    // For presentation, stay where user is
                }
                .onChange(of: keyboardHeight) { _ in
                    // Scroll when keyboard appears
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }
            }
            
            // Chat input (only in LIVE mode) - Fixed at bottom
            if canChat && isLive {
                ChatInputBar(
                    messageText: $messageText,
                    isFocused: $isInputFocused,
                    onSend: {
                        guard !messageText.isEmpty else { return }
                        onSendMessage?(messageText)
                        messageText = ""
                        isInputFocused = false
                    },
                    onLike: {
                        // Send like animation
                    }
                )
            }
        }
        .background(Color(hex: "1B1B25"))
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    // Swipe down to dismiss keyboard
                    if value.translation.height > 50 {
                        isInputFocused = false
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
        )
        .onAppear {
            setupKeyboardObservers()
        }
        .onDisappear {
            removeKeyboardObservers()
        }
    }
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            withAnimation(.easeOut(duration: 0.3)) {
                keyboardHeight = keyboardFrame.height
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { _ in
            withAnimation(.easeOut(duration: 0.3)) {
                keyboardHeight = 0
            }
        }
    }
    
    private func removeKeyboardObservers() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
}

#Preview {
    ChatListView(
        messages: [
            ChatMessage(username: "MatchMaster", text: "Beste kampen!", usernameColor: .orange, likes: 5, timestamp: Date()),
            ChatMessage(username: "SportsFan23", text: "KJØR PÅ!!!", usernameColor: .cyan, likes: 3, timestamp: Date().addingTimeInterval(-30))
        ],
        viewerCount: 1234
    )
}


