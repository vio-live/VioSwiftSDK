import SwiftUI
import Combine

struct VGChatOverlay: View {
    @StateObject private var chatManager = ChatManager()
    @State private var isExpanded = false
    @State private var dragOffset: CGFloat = 0
    @State private var messageText = ""
    @State private var floatingLikes: [FloatingLike] = []
    @FocusState private var isTextFieldFocused: Bool
    @State private var keyboardHeight: CGFloat = 0
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
    
    struct FloatingLike: Identifiable { let id = UUID(); let xOffset: CGFloat }
    
    private var isLandscape: Bool { verticalSizeClass == .compact }
    
    private var shouldShowChat: Bool {
        if isExpanded { return true }
        if isLandscape { return showControls }
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
                                            let t = value.translation.height
                                            dragOffset = isExpanded ? max(0, t) : min(0, t)
                                        }
                                        .onEnded { value in
                                            let threshold: CGFloat = 50
                                            let velocity = value.predictedEndTranslation.height
                                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                                if isExpanded {
                                                    if dragOffset > threshold || velocity > 500 { isExpanded = false; onExpandedChange?(false) }
                                                } else {
                                                    if dragOffset < -threshold || velocity < -500 { isExpanded = true; onExpandedChange?(true) }
                                                }
                                                dragOffset = 0
                                            }
                                        }
                                )
                            if isExpanded { chatContent.frame(height: chatContentHeight(geometry: geometry)) }
                        }
                        .frame(height: chatPanelHeight(geometry: geometry))
                        .offset(y: dragOffset - keyboardHeight)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.black.opacity(0.4))
                                .background(
                                    RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial)
                                )
                                .shadow(color: Color.black.opacity(0.6), radius: 20, x: 0, y: -8)
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    .padding(.bottom, 0)
                    .ignoresSafeArea(edges: .bottom)
                }
                
                ForEach(floatingLikes) { like in
                    VGLikeView()
                        .offset(x: like.xOffset, y: geometry.size.height)
                        .animation(.easeOut(duration: 2.5), value: floatingLikes.count)
                        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { floatingLikes.removeAll { $0.id == like.id } } }
                }
            }
        }
        .onAppear { chatManager.startSimulation(); setupKeyboardObservers() }
        .onDisappear { chatManager.stopSimulation(); removeKeyboardObservers() }
    }
    
    private func chatPanelHeight(geometry: GeometryProxy) -> CGFloat {
        if !isExpanded { return isLandscape ? collapsedHeight : 60 }
        if isTextFieldFocused { return geometry.size.height * compactHeight }
        return geometry.size.height * expandedHeight
    }
    
    private func chatContentHeight(geometry: GeometryProxy) -> CGFloat {
        let handleHeight = isLandscape ? collapsedHeight : 60
        if isTextFieldFocused { return geometry.size.height * compactHeight - handleHeight }
        return geometry.size.height * expandedHeight - handleHeight
    }
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
            guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            withAnimation(.easeOut(duration: 0.3)) { keyboardHeight = frame.height }
        }
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
            withAnimation(.easeOut(duration: 0.3)) { keyboardHeight = 0 }
        }
    }
    
    private func removeKeyboardObservers() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    private var dragHandle: some View {
        VStack(spacing: isLandscape ? 2 : 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.white.opacity(0.3))
                .frame(width: isLandscape ? 28 : 32, height: isLandscape ? 3 : 4)
                .padding(.top, isLandscape ? 4 : 6)
            HStack(spacing: isLandscape ? 6 : 8) {
                HStack(spacing: isLandscape ? 3 : 4) {
                    Text("Sponset av")
                        .font(.system(size: isLandscape ? 8 : 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                    AsyncImage(url: URL(string: "http://event-streamer-angelo100.replit.app/objects/uploads/16475fd2-da1f-4e9f-8eb4-362067b27858")) { phase in
                        switch phase {
                        case .success(let image): image.resizable().aspectRatio(contentMode: .fit).frame(maxWidth: isLandscape ? 50 : 70, maxHeight: isLandscape ? 16 : 24)
                        case .empty: ProgressView().scaleEffect(isLandscape ? 0.4 : 0.5).frame(width: isLandscape ? 50 : 70, height: isLandscape ? 16 : 24)
                        case .failure: EmptyView()
                        @unknown default: EmptyView()
                        }
                    }
                }
                .padding(.horizontal, isLandscape ? 6 : 10)
                .padding(.vertical, isLandscape ? 3 : 5)
                .background(RoundedRectangle(cornerRadius: isLandscape ? 4 : 6).fill(Color.black.opacity(0.3)))
                
                Spacer()
                
                Button(action: { withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { isExpanded.toggle(); onExpandedChange?(isExpanded) } }) {
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
    
    private var chatContent: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(chatManager.messages) { message in
                            VGChatMessageRow(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(12)
                }
                .background(Color(red: 0.05, green: 0.05, blue: 0.05))
                .onChange(of: chatManager.messages.count) { _ in
                    if let last = chatManager.messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                }
            }
            chatInputBar
        }
    }
    
    private var chatInputBar: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(LinearGradient(colors: [VGTheme.Colors.red, VGTheme.Colors.white], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 28, height: 28)
                .overlay(Text("A").font(.system(size: 13, weight: .semibold)).foregroundColor(.white))
            TextField("Send a message...", text: $messageText)
                .font(.system(size: 13))
                .foregroundColor(.white)
                .accentColor(VGTheme.Colors.red)
                .focused($isTextFieldFocused)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.1)))
                .onSubmit { sendMessage() }
            Button(action: { sendFloatingLike() }) {
                Image(systemName: "hand.thumbsup.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(VGTheme.Colors.red)
                    .padding(10)
                    .background(Circle().fill(VGTheme.Colors.red.opacity(0.2)))
            }
            Button(action: { sendMessage() }) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(messageText.isEmpty ? .white.opacity(0.3) : VGTheme.Colors.red)
                    .padding(10)
                    .background(Circle().fill(messageText.isEmpty ? Color.white.opacity(0.1) : VGTheme.Colors.red.opacity(0.2)))
            }
            .disabled(messageText.isEmpty)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .padding(.bottom, 8)
        .background(Color(red: 0.05, green: 0.05, blue: 0.05))
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let message = ChatMessage(username: "VGUser", text: messageText, usernameColor: VGTheme.Colors.red, likes: 0, timestamp: Date())
        chatManager.addMessage(message)
        messageText = ""
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { isTextFieldFocused = false }
    }
    
    private func sendFloatingLike() {
        let like = FloatingLike(xOffset: CGFloat.random(in: -80...80))
        withAnimation { floatingLikes.append(like) }
    }
}

struct VGChatMessageRow: View {
    let message: ChatMessage
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(message.usernameColor.opacity(0.3))
                .frame(width: 28, height: 28)
                .overlay(Text(String(message.username.prefix(1))).font(.system(size: 13, weight: .semibold)).foregroundColor(message.usernameColor))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(message.username).font(.system(size: 13, weight: .bold)).foregroundColor(message.usernameColor)
                    Text(timeAgo(from: message.timestamp)).font(.system(size: 10)).foregroundColor(.white.opacity(0.4))
                }
                Text(message.text).font(.system(size: 14)).foregroundColor(.white.opacity(0.95)).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
    private func timeAgo(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date)); if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60; if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60; return "\(hours)h"
    }
}

struct VGLikeView: View {
    @State private var yOffset: CGFloat = 0
    @State private var opacity: Double = 1.0
    @State private var scale: CGFloat = 1.0
    @State private var rotation: Double = 0
    var body: some View {
        Image(systemName: "hand.thumbsup.fill")
            .font(.system(size: 32, weight: .bold))
            .foregroundColor(VGTheme.Colors.red)
            .shadow(color: VGTheme.Colors.red.opacity(0.5), radius: 8, x: 0, y: 0)
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

struct ChatMessage: Identifiable {
    let id = UUID()
    let username: String
    let text: String
    let usernameColor: Color
    let likes: Int
    let timestamp: Date
}

@MainActor
class ChatManager: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var viewerCount: Int = 0
    private var timer: Timer?
    private var viewerTimer: Timer?
    private let maxMessages = 100
    private let simulatedUsers: [(String, Color)] = [
        ("VGFan", VGTheme.Colors.red), ("NewsLive", .orange), ("SportPro", .green), ("NorgeFan", .blue), ("Analyst", .purple)
    ]
    private let simulatedMessages: [String] = [
        "For et mål!", "Utrolig redning!", "Dommeren tuller", "Kjør på!", "Helt rått!", "Nå skjer det!"
    ]
    func startSimulation() {
        viewerCount = Int.random(in: 8000...15000)
        for _ in 0..<5 { addSimulatedMessage() }
        scheduleNextMessage()
        viewerTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let change = Int.random(in: -100...200)
            self.viewerCount = max(5000, self.viewerCount + change)
        }
    }
    func stopSimulation() { timer?.invalidate(); viewerTimer?.invalidate(); timer = nil; viewerTimer = nil }
    func addMessage(_ message: ChatMessage) {
        messages.append(message)
        if messages.count > maxMessages { messages.removeFirst() }
    }
    private func scheduleNextMessage() {
        let interval = Double.random(in: 1.5...4.0)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.addSimulatedMessage(); self?.scheduleNextMessage()
        }
    }
    private func addSimulatedMessage() {
        let user = simulatedUsers.randomElement()!
        let text = simulatedMessages.randomElement()!
        let message = ChatMessage(username: user.0, text: text, usernameColor: user.1, likes: Int.random(in: 0...12), timestamp: Date())
        messages.append(message)
        if messages.count > maxMessages { messages.removeFirst() }
    }
}


