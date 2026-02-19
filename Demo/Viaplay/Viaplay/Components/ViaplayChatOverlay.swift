// Copiado y adaptado de TV2ChatOverlay.swift de tv2demo
import SwiftUI
import Combine

// Import shared chat models
import struct Viaplay.ChatMessage

struct ViaplayChatOverlay: View {
    @StateObject private var chatManager = ChatManager()
    @State private var isExpanded = false
    @State private var dragOffset: CGFloat = 0
    @State private var messageText = ""
    @State private var floatingLikes: [FloatingLike] = []
    @FocusState private var isTextFieldFocused: Bool
    @State private var keyboardHeight: CGFloat = 0
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    var onExpandedChange: ((Bool) -> Void)?
    @Binding var showControls: Bool
    
    init(showControls: Binding<Bool>, onExpandedChange: ((Bool) -> Void)? = nil) {
        self._showControls = showControls
        self.onExpandedChange = onExpandedChange
    }
    
    private let expandedHeight: CGFloat = 0.4
    private let collapsedHeight: CGFloat = 40
    private let compactHeight: CGFloat = 0.25
    
    struct FloatingLike: Identifiable {
        let id = UUID()
        let xOffset: CGFloat
    }
    
    private var isLandscape: Bool {
        verticalSizeClass == .compact
    }
    
    private var shouldShowChat: Bool {
        if isExpanded {
            return true
        }
        if isLandscape {
            return showControls
        }
        return true
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if shouldShowChat {
                    VStack(spacing: 0) {
                        Spacer()
                        VStack(spacing: 0) {
                            dragHandle
                                .highPriorityGesture(
                                    DragGesture(minimumDistance: 10)
                                        .onChanged { value in
                                            let translation = value.translation.height
                                            if isExpanded {
                                                dragOffset = max(0, translation)
                                            } else {
                                                dragOffset = min(0, translation)
                                            }
                                        }
                                        .onEnded { value in
                                            let threshold: CGFloat = 50
                                            let velocity = value.predictedEndTranslation.height
                                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                                if isExpanded {
                                                    if dragOffset > threshold || velocity > 500 {
                                                        isExpanded = false
                                                        onExpandedChange?(false)
                                                    }
                                                } else {
                                                    if dragOffset < -threshold || velocity < -500 {
                                                        isExpanded = true
                                                        onExpandedChange?(true)
                                                    }
                                                }
                                                dragOffset = 0
                                            }
                                        }
                                )
                            if isExpanded {
                                chatContent
                                    .frame(height: chatContentHeight(geometry: geometry))
                            }
                        }
                        .frame(height: chatPanelHeight(geometry: geometry))
                        .offset(y: dragOffset - keyboardHeight)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(ViaplayTheme.Colors.darkGray.opacity(0.4))
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(.ultraThinMaterial)
                                )
                                .shadow(color: Color.black.opacity(0.6), radius: 20, x: 0, y: -8)
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    .padding(.bottom, isTextFieldFocused ? 0 : 0)
                    .ignoresSafeArea(edges: .bottom)
                }
                // Floating likes overlay
                ForEach(floatingLikes) { like in
                    FloatingLikeView()
                        .offset(x: like.xOffset, y: geometry.size.height)
                        .animation(.easeOut(duration: 2.5), value: floatingLikes.count)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                floatingLikes.removeAll { $0.id == like.id }
                            }
                        }
                }
            }
        }
        .onAppear {
            chatManager.startSimulation()
            setupKeyboardObservers()
        }
        .onDisappear {
            chatManager.stopSimulation()
            removeKeyboardObservers()
        }
    }
    // MARK: - Helpers
    private func chatPanelHeight(geometry: GeometryProxy) -> CGFloat {
        if !isExpanded {
            return isLandscape ? collapsedHeight : 60
        }
        if isTextFieldFocused {
            return geometry.size.height * compactHeight
        }
        return geometry.size.height * expandedHeight
    }
    private func chatContentHeight(geometry: GeometryProxy) -> CGFloat {
        let handleHeight = isLandscape ? collapsedHeight : 60
        if isTextFieldFocused {
            return geometry.size.height * compactHeight - handleHeight
        }
        return geometry.size.height * expandedHeight - handleHeight
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
    // MARK: - Drag Handle
    private var dragHandle: some View {
        VStack(spacing: isLandscape ? 2 : 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.white.opacity(0.3))
                .frame(width: isLandscape ? 28 : 32, height: isLandscape ? 3 : 4)
                .padding(.top, isLandscape ? 4 : 6)
            HStack(spacing: isLandscape ? 6 : 8) {
                // Sponsor badge (top left) - Campaign logo from CampaignManager
                CampaignSponsorBadge(
                    maxWidth: isLandscape ? 40 : 60,
                    maxHeight: isLandscape ? 12 : 18,
                    alignment: .leading
                )
                .padding(.horizontal, isLandscape ? 6 : 10)
                .padding(.vertical, isLandscape ? 3 : 5)
                .background(
                    RoundedRectangle(cornerRadius: isLandscape ? 4 : 6)
                        .fill(Color.black.opacity(0.3))
                )
                
                Spacer()
                
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        isExpanded.toggle()
                        onExpandedChange?(isExpanded)
                    }
                }) {
                    HStack(spacing: 4) {
                        Text("LIVE CHAT")
                            .font(.system(size: isLandscape ? 10 : 13, weight: .bold))
                            .foregroundColor(.white)
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                            .font(.system(size: isLandscape ? 10 : 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
            }
            .padding(.horizontal, isLandscape ? 12 : 14)
            .padding(.bottom, isLandscape ? 4 : 8)
        }
        .frame(height: isLandscape ? collapsedHeight : 60)
        .contentShape(Rectangle())
    }
    // MARK: - Chat Content
    private var chatContent: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(chatManager.messages) { message in
                            ChatMessageRow(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(12)
                }
                .background(ViaplayTheme.Colors.black)
                .onChange(of: chatManager.messages.count) { _ in
                    if let lastMessage = chatManager.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            chatInputBar
        }
    }
    // MARK: - Chat Input Bar
    private var chatInputBar: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(ViaplayTheme.Colors.brandGradient)
                .frame(width: 28, height: 28)
                .overlay(
                    Text("A")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                )
            TextField("Send a message...", text: $messageText)
                .font(.system(size: 13))
                .foregroundColor(.white)
                .accentColor(ViaplayTheme.Colors.pink)
                .focused($isTextFieldFocused)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.white.opacity(0.1))
                )
                .onSubmit {
                    sendMessage()
                }
            Button(action: {
                sendFloatingLike()
            }) {
                Image(systemName: "hand.thumbsup.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(ViaplayTheme.Colors.pink)
                    .padding(10)
                    .background(
                        Circle()
                            .fill(ViaplayTheme.Colors.pink.opacity(0.2))
                    )
            }
            Button(action: {
                sendMessage()
            }) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(messageText.isEmpty ? .white.opacity(0.3) : ViaplayTheme.Colors.pink)
                    .padding(10)
                    .background(
                        Circle()
                            .fill(messageText.isEmpty ? Color.white.opacity(0.1) : ViaplayTheme.Colors.pink.opacity(0.2))
                    )
            }
            .disabled(messageText.isEmpty)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .padding(.bottom, 8)
        .background(ViaplayTheme.Colors.black)
    }
    // MARK: - Actions
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let message = ChatMessage(
            username: "Angelo",
            text: messageText,
            usernameColor: ViaplayTheme.Colors.pink,
            likes: 0,
            timestamp: Date()
        )
        chatManager.addMessage(message)
        messageText = ""
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isTextFieldFocused = false
        }
    }
    private func sendFloatingLike() {
        let randomOffset = CGFloat.random(in: -80...80)
        let like = FloatingLike(xOffset: randomOffset)
        withAnimation {
            floatingLikes.append(like)
        }
    }
}
// MARK: - Chat Message Row
// NOTE: Using ChatMessageRow from Components/Chat/ChatMessageRow.swift
// MARK: - Chat Message Model
// NOTE: Using ChatMessage from Models/Chat/ChatModels.swift
// MARK: - Chat Manager
// NOTE: Using ChatManager from Managers/Chat/ChatManager.swift
// MARK: - Floating Like View
struct FloatingLikeView: View {
    @State private var yOffset: CGFloat = 0
    @State private var opacity: Double = 1.0
    @State private var scale: CGFloat = 1.0
    @State private var rotation: Double = 0
    var body: some View {
        Image(systemName: "hand.thumbsup.fill")
            .font(.system(size: 32, weight: .bold))
            .foregroundColor(ViaplayTheme.Colors.pink)
            .shadow(color: ViaplayTheme.Colors.pink.opacity(0.5), radius: 8, x: 0, y: 0)
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotation))
            .opacity(opacity)
            .offset(y: yOffset)
            .onAppear {
                withAnimation(.easeOut(duration: 2.5)) {
                    yOffset = -UIScreen.main.bounds.height
                    opacity = 0
                    scale = 1.5
                    rotation = Double.random(in: -30...30)
                }
            }
    }
}
