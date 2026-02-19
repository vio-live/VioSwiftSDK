import SwiftUI
import VioCore
import VioLiveShow
import VioDesignSystem
import VioUI

// MARK: - Layout 1: Full Screen Overlay (como TikTok/Instagram Live)

/// Full screen live stream overlay - Similar to TikTok/Instagram Live
public struct RLiveStreamFullScreenOverlay: View {
    
    @ObservedObject private var liveShowManager = LiveShowManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var cartManager: CartManager
    
    let stream: LiveStream
    let onDismiss: () -> Void
    
    // State for interactions
    @State private var showChat = true
    @State private var showShoppingPanel = true
    @State private var currentProductIndex = 0
    
    // Colors based on theme
    private var adaptiveColors: AdaptiveColors {
        VioColors.adaptive(for: colorScheme)
    }
    
    public init(stream: LiveStream, onDismiss: @escaping () -> Void) {
        self.stream = stream
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        ZStack {
            // Background Video (Mock with image for now)
            videoPlayerBackground
            
            // Gradient overlay for readability
            gradientOverlay
            
            // UI Elements
            VStack {
                // Top section - Stream info and controls
                topSection
                
                Spacer()
                
                // Bottom section - Chat and shopping
                bottomSection
            }
            .padding()
        }
        .ignoresSafeArea()
        .onAppear {
            // Simulate live updates
            startLiveSimulation()
        }
    }
    
    // MARK: - Video Background
    
    private var videoPlayerBackground: some View {
        AsyncImage(url: URL(string: stream.thumbnailUrl ?? "")) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            Rectangle()
                .fill(LinearGradient(
                    colors: [adaptiveColors.primary.opacity(0.3), adaptiveColors.secondary.opacity(0.5)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
        }
        .clipped()
    }
    
    private var gradientOverlay: some View {
        LinearGradient(
            colors: [
                Color.black.opacity(0.4),
                Color.black.opacity(0.1),
                Color.black.opacity(0.6)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    // MARK: - Top Section
    
    private var topSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                // Live indicator
                liveIndicator
                
                // Streamer info
                streamerInfo
            }
            
            Spacer()
            
            // Controls
            VStack(spacing: 16) {
                closeButton
                shareButton
                miniPlayerButton
            }
        }
    }
    
    private var liveIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .scaleEffect(1.0)
                .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: true)
            
            Text("LIVE")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
            
            Text("• \(stream.viewerCount) Viewers")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.6))
        .cornerRadius(15)
    }
    
    private var streamerInfo: some View {
        HStack(spacing: 12) {
            // Avatar
            AsyncImage(url: URL(string: stream.streamer.avatarUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(adaptiveColors.surfaceSecondary)
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(stream.streamer.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    if stream.streamer.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 12))
                    }
                }
                
                Text(stream.streamer.username)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
                
                Text(stream.title)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
            }
        }
    }
    
    // MARK: - Controls
    
    private var closeButton: some View {
        Button(action: onDismiss) {
            Image(systemName: "xmark")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(Color.black.opacity(0.6))
                .clipShape(Circle())
        }
    }
    
    private var shareButton: some View {
        Button(action: {}) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 18))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(Color.black.opacity(0.6))
                .clipShape(Circle())
        }
    }
    
    private var miniPlayerButton: some View {
        Button(action: {
            liveShowManager.showMiniPlayer()
        }) {
            Image(systemName: "pip.enter")
                .font(.system(size: 18))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(Color.black.opacity(0.6))
                .clipShape(Circle())
        }
    }
    
    // MARK: - Bottom Section
    
    private var bottomSection: some View {
        HStack(alignment: .bottom, spacing: 16) {
            // Chat section
            if showChat {
                liveChatSection
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Shopping panel
            if showShoppingPanel && !stream.featuredProducts.isEmpty {
                liveShoppingSection
                    .frame(width: 160)
            }
        }
    }
    
    private var liveChatSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Recent chat messages
            ForEach(stream.chatMessages.prefix(4).reversed(), id: \.id) { message in
                chatMessageView(message)
            }
            
            // Chat input
            chatInputView
        }
    }
    
    private func chatMessageView(_ message: LiveChatMessage) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(message.user.username)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(message.isStreamerMessage ? .yellow : .white)
            +
            Text(" \(message.message)")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.9))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.6))
        .cornerRadius(20)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    
    private var chatInputView: some View {
        HStack {
            Text("Say something...")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
            
            Spacer()
            
            Button(action: {}) {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 16))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.4))
        .cornerRadius(25)
    }
    
    // MARK: - Shopping Section
    
    private var liveShoppingSection: some View {
        VStack(spacing: 12) {
            // Featured products carousel
            if !stream.featuredProducts.isEmpty {
                featuredProductCard
            }
        }
    }
    
    private var featuredProductCard: some View {
        let product = stream.featuredProducts[currentProductIndex % stream.featuredProducts.count]
        
        return VStack(spacing: 12) {
            // Product image
            AsyncImage(url: URL(string: product.imageUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(adaptiveColors.surfaceSecondary)
            }
            .frame(width: 120, height: 120)
            .cornerRadius(12)
            .clipped()
            
            VStack(spacing: 8) {
                // Product info
                Text(product.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                
                // Price - uses amount_incl_taxes if available
                HStack(spacing: 4) {
                    if let originalPrice = product.originalPrice,
                       let compareAtPrice = originalPrice.formattedCompareAtPrice {
                        Text(compareAtPrice)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                            .strikethrough()
                    }
                    
                    Text(product.price.formattedPrice)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
                
                // Special offer
                if let offer = product.specialOffer {
                    Text(offer)
                        .font(.system(size: 10))
                        .foregroundColor(.yellow)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                
                // Action buttons
                VStack(spacing: 8) {
                    Button(action: {
                        LiveShowManager.shared.quickBuyProduct(product, cartManager: cartManager)
                    }) {
                        Text("Order now")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.white)
                            .cornerRadius(20)
                    }
                    
                    Button(action: {
                        LiveShowManager.shared.addProductToCart(product, cartManager: cartManager)
                    }) {
                        Text("Add to cart")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(15)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.black.opacity(0.7))
        .cornerRadius(16)
        .onTapGesture {
            // Cycle through products
            withAnimation(.spring()) {
                currentProductIndex = (currentProductIndex + 1) % stream.featuredProducts.count
            }
        }
    }
    
    // MARK: - Live Simulation
    
    private func startLiveSimulation() {
        // Simulate new chat messages
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            Task { @MainActor in
                withAnimation(.spring()) {
                    liveShowManager.simulateNewChatMessage()
                }
            }
        }
        
        // Cycle through products
        Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { _ in
            withAnimation(.spring()) {
                currentProductIndex = (currentProductIndex + 1) % max(1, stream.featuredProducts.count)
            }
        }
    }
}

// MARK: - Layout 2: Bottom Sheet

/// Bottom sheet live stream layout
public struct RLiveStreamBottomSheet: View {
    
    let stream: LiveStream
    let onDismiss: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var cartManager: CartManager
    
    private var adaptiveColors: AdaptiveColors {
        VioColors.adaptive(for: colorScheme)
    }
    
    public init(stream: LiveStream, onDismiss: @escaping () -> Void) {
        self.stream = stream
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Handle
            RoundedRectangle(cornerRadius: 2.5)
                .fill(adaptiveColors.textSecondary)
                .frame(width: 40, height: 5)
                .padding(.top, 8)
            
            // Content
            ScrollView {
                VStack(spacing: 20) {
                    // Video player (compact)
                    videoSection
                    
                    // Stream info
                    streamInfoSection
                    
                    // Featured products
                    if !stream.featuredProducts.isEmpty {
                        productsSection
                    }
                    
                    // Chat
                    chatSection
                }
                .padding()
            }
        }
        .background(adaptiveColors.surface)
        .cornerRadius(16)
    }
    
    private var videoSection: some View {
        AsyncImage(url: URL(string: stream.thumbnailUrl ?? "")) { image in
            image
                .resizable()
                .aspectRatio(16/9, contentMode: .fill)
        } placeholder: {
            Rectangle()
                .fill(adaptiveColors.surfaceSecondary)
                .aspectRatio(16/9, contentMode: .fit)
        }
        .cornerRadius(12)
        .clipped()
        .overlay(
            VStack {
                HStack {
                    liveIndicatorCompact
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                }
                Spacer()
                
                // Play button
                Button(action: {
                    // Expand to full screen
                    LiveShowManager.shared.showLiveStream(stream, layout: .fullScreenOverlay)
                }) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Color.black.opacity(0.7))
                        .clipShape(Circle())
                }
            }
            .padding()
        )
    }
    
    private var liveIndicatorCompact: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color.red)
                .frame(width: 6, height: 6)
            
            Text("LIVE")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.7))
        .cornerRadius(10)
    }
    
    private var streamInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(stream.title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(adaptiveColors.textPrimary)
            
            HStack {
                AsyncImage(url: URL(string: stream.streamer.avatarUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle().fill(adaptiveColors.surfaceSecondary)
                }
                .frame(width: 24, height: 24)
                .clipShape(Circle())
                
                Text(stream.streamer.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(adaptiveColors.textPrimary)
                
                if stream.streamer.isVerified {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 12))
                }
                
                Spacer()
                
                Text("\(stream.viewerCount) viewers")
                    .font(.system(size: 12))
                    .foregroundColor(adaptiveColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var productsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Featured Products")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(adaptiveColors.textPrimary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(stream.featuredProducts, id: \.id) { product in
                        compactProductCard(product)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private func compactProductCard(_ product: LiveProduct) -> some View {
        VStack(spacing: 8) {
            AsyncImage(url: URL(string: product.imageUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle().fill(adaptiveColors.surfaceSecondary)
            }
            .frame(width: 80, height: 80)
            .cornerRadius(8)
            .clipped()
            
            Text(product.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(adaptiveColors.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            
            Text(product.price.formattedPrice)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(adaptiveColors.primary)
        }
        .frame(width: 100)
        .onTapGesture {
            LiveShowManager.shared.addProductToCart(product, cartManager: cartManager)
        }
    }
    
    private var chatSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Live Chat")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(adaptiveColors.textPrimary)
            
            VStack(spacing: 8) {
                ForEach(stream.chatMessages.prefix(6), id: \.id) { message in
                    HStack(alignment: .top, spacing: 8) {
                        Text(message.user.username)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(adaptiveColors.primary)
                        
                        Text(message.message)
                            .font(.system(size: 12))
                            .foregroundColor(adaptiveColors.textPrimary)
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

// MARK: - Layout 3: Modal

/// Modal live stream layout
public struct RLiveStreamModal: View {
    
    let stream: LiveStream
    let onDismiss: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var cartManager: CartManager
    
    private var adaptiveColors: AdaptiveColors {
        VioColors.adaptive(for: colorScheme)
    }
    
    public init(stream: LiveStream, onDismiss: @escaping () -> Void) {
        self.stream = stream
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Video player
                videoPlayerSection
                
                // Content tabs
                contentTabs
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close", action: onDismiss)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        LiveShowManager.shared.showMiniPlayer()
                    }) {
                        Image(systemName: "pip.enter")
                    }
                }
            }
            #else
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Close", action: onDismiss)
                }
            }
            #endif
        }
        .background(adaptiveColors.background)
    }
    
    private var videoPlayerSection: some View {
        AsyncImage(url: URL(string: stream.thumbnailUrl ?? "")) { image in
            image
                .resizable()
                .aspectRatio(16/9, contentMode: .fill)
        } placeholder: {
            Rectangle()
                .fill(adaptiveColors.surfaceSecondary)
                .aspectRatio(16/9, contentMode: .fit)
        }
        .clipped()
        .overlay(
            VStack {
                HStack {
                    liveIndicatorCompact
                    Spacer()
                }
                Spacer()
                
                // Play button
                Button(action: {
                    // Switch to full screen
                    LiveShowManager.shared.showLiveStream(stream, layout: .fullScreenOverlay)
                }) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(Color.black.opacity(0.7))
                        .clipShape(Circle())
                }
            }
            .padding()
        )
    }
    
    private var liveIndicatorCompact: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color.red)
                .frame(width: 6, height: 6)
            
            Text("LIVE • \(stream.viewerCount) viewers")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.7))
        .cornerRadius(10)
    }
    
    private var contentTabs: some View {
        TabView {
            // Stream info tab
            streamInfoTab
                .tabItem {
                    Label("Info", systemImage: "info.circle")
                }
            
            // Products tab
            if !stream.featuredProducts.isEmpty {
                productsTab
                    .tabItem {
                        Label("Products", systemImage: "bag")
                    }
            }
            
            // Chat tab
            chatTab
                .tabItem {
                    Label("Chat", systemImage: "bubble.left.and.bubble.right")
                }
        }
        .background(adaptiveColors.background)
    }
    
    private var streamInfoTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Streamer info
                HStack(spacing: 12) {
                    AsyncImage(url: URL(string: stream.streamer.avatarUrl ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle().fill(adaptiveColors.surfaceSecondary)
                    }
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(stream.streamer.name)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(adaptiveColors.textPrimary)
                            
                            if stream.streamer.isVerified {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        Text("\(stream.streamer.followerCount) followers")
                            .font(.system(size: 14))
                            .foregroundColor(adaptiveColors.textSecondary)
                    }
                    
                    Spacer()
                }
                
                // Stream details
                VStack(alignment: .leading, spacing: 8) {
                    Text(stream.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(adaptiveColors.textPrimary)
                    
                    if let description = stream.description {
                        Text(description)
                            .font(.system(size: 14))
                            .foregroundColor(adaptiveColors.textSecondary)
                    }
                }
            }
            .padding()
        }
    }
    
    private var productsTab: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                ForEach(stream.featuredProducts, id: \.id) { product in
                    modalProductCard(product)
                }
            }
            .padding()
        }
    }
    
    private func modalProductCard(_ product: LiveProduct) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: URL(string: product.imageUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle().fill(adaptiveColors.surfaceSecondary)
            }
            .frame(height: 120)
            .cornerRadius(8)
            .clipped()
            
            Text(product.title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(adaptiveColors.textPrimary)
                .lineLimit(2)
            
            HStack {
                // Use compare_at_incl_taxes if available for original price
                if let originalPrice = product.originalPrice,
                   let compareAtPrice = originalPrice.formattedCompareAtPrice {
                    Text(compareAtPrice)
                        .font(.system(size: 12))
                        .foregroundColor(adaptiveColors.textSecondary)
                        .strikethrough()
                }
                
                Text(product.price.formattedPrice)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(adaptiveColors.primary)
            }
            
            Button(action: {
                ToastManager.shared.showSuccess("Added \(product.title) to cart")
            }) {
                Text("Add to Cart")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(adaptiveColors.primary)
                    .cornerRadius(6)
            }
        }
        .padding()
        .background(adaptiveColors.surface)
        .cornerRadius(12)
    }
    
    private var chatTab: some View {
        VStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(stream.chatMessages, id: \.id) { message in
                        chatMessageRow(message)
                    }
                }
                .padding()
            }
            
            // Chat input
            HStack {
                TextField("Type a message...", text: .constant(""))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button("Send") {
                    // Send message action
                }
                .foregroundColor(adaptiveColors.primary)
            }
            .padding()
        }
    }
    
    private func chatMessageRow(_ message: LiveChatMessage) -> some View {
        HStack(alignment: .top, spacing: 8) {
            AsyncImage(url: URL(string: message.user.avatarUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle().fill(adaptiveColors.surfaceSecondary)
            }
            .frame(width: 30, height: 30)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(message.user.username)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(adaptiveColors.primary)
                    
                    if message.user.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 10))
                    }
                    
                    Spacer()
                    
                    Text(message.timestamp, style: .time)
                        .font(.system(size: 10))
                        .foregroundColor(adaptiveColors.textTertiary)
                }
                
                Text(message.message)
                    .font(.system(size: 14))
                    .foregroundColor(adaptiveColors.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Helper Extensions

#if os(iOS)
import UIKit

extension View {
    func customCornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
#endif
