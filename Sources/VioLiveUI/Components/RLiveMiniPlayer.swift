import SwiftUI
import VioCore
import VioLiveShow
import VioDesignSystem
import VioUI
import VioLiveShow

/// Mini player for live streams - Draggable and expandable
public struct RLiveMiniPlayer: View {
    
    @ObservedObject private var liveShowManager = LiveShowManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var cartManager: CartManager
    
    let stream: LiveStream
    let onDismiss: () -> Void
    
    // Dragging state
    @State private var dragOffset = CGSize.zero
    @State private var lastDragPosition = CGPoint.zero
    @State private var isDragging = false
    
    // Animation state
    @State private var isVisible = false
    
    // Colors based on theme
    private var adaptiveColors: AdaptiveColors {
        VioColors.adaptive(for: colorScheme)
    }
    
    public init(stream: LiveStream, onDismiss: @escaping () -> Void) {
        self.stream = stream
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        GeometryReader { geometry in
            miniPlayerContent
                .frame(width: 120, height: 160)
                .position(playerPosition(in: geometry))
                .scaleEffect(isVisible ? 1.0 : 0.1)
                .opacity(isVisible ? 1.0 : 0.0)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isVisible)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: dragOffset)
                .onAppear {
                    withAnimation {
                        isVisible = true
                    }
                }
        }
        .allowsHitTesting(true)
    }
    
    private var miniPlayerContent: some View {
        VStack(spacing: 0) {
            // Video thumbnail
            videoSection
            
            // Controls section
            controlsSection
        }
        .background(adaptiveColors.surface)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
        .gesture(dragGesture)
        .onTapGesture {
            // Expand to full screen
            liveShowManager.expandFromMiniPlayer()
        }
    }
    
    private var videoSection: some View {
        ZStack {
            // Video thumbnail
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
            .frame(height: 100)
            .clipped()
            
            // Overlay elements
            VStack {
                HStack {
                    liveIndicator
                    Spacer()
                    closeButton
                }
                Spacer()
                
                // Play indicator
                playIndicator
            }
            .padding(8)
        }
        .cornerRadius(12)
    }
    
    private var liveIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color.red)
                .frame(width: 4, height: 4)
                .scaleEffect(1.0)
                .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: true)
            
            Text("LIVE")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.black.opacity(0.7))
        .cornerRadius(8)
    }
    
    private var closeButton: some View {
        Button(action: onDismiss) {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Color.black.opacity(0.7))
                .clipShape(Circle())
        }
    }
    
    private var playIndicator: some View {
        Image(systemName: "play.fill")
            .font(.system(size: 12))
            .foregroundColor(.white)
            .frame(width: 24, height: 24)
            .background(Color.black.opacity(0.7))
            .clipShape(Circle())
    }
    
    private var controlsSection: some View {
        VStack(spacing: 4) {
            // Streamer info
            HStack(spacing: 6) {
                AsyncImage(url: URL(string: stream.streamer.avatarUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle().fill(adaptiveColors.surfaceSecondary)
                }
                .frame(width: 16, height: 16)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(stream.streamer.name)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(adaptiveColors.textPrimary)
                        .lineLimit(1)
                    
                    Text("\(stream.viewerCount) viewers")
                        .font(.system(size: 8))
                        .foregroundColor(adaptiveColors.textSecondary)
                }
                
                Spacer()
            }
            
            // Featured product (if any)
            if let firstProduct = stream.featuredProducts.first {
                miniProductView(firstProduct)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }
    
    private func miniProductView(_ product: LiveProduct) -> some View {
        HStack(spacing: 4) {
            AsyncImage(url: URL(string: product.imageUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle().fill(adaptiveColors.surfaceSecondary)
            }
            .frame(width: 20, height: 20)
            .cornerRadius(4)
            .clipped()
            
            VStack(alignment: .leading, spacing: 1) {
                Text(product.title)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(adaptiveColors.textPrimary)
                    .lineLimit(1)
                
                Text(product.price.formattedPrice)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(adaptiveColors.primary)
            }
            
            Spacer()
            
            Button(action: {
                LiveShowManager.shared.addProductToCart(product, cartManager: cartManager)
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 16, height: 16)
                    .background(adaptiveColors.primary)
                    .clipShape(Circle())
            }
        }
    }
    
    // MARK: - Positioning Logic
    
    private func playerPosition(in geometry: GeometryProxy) -> CGPoint {
        let defaultPosition = CGPoint(
            x: geometry.size.width - 80, // 20px from right edge + half width
            y: geometry.size.height - 200 // 120px from bottom + half height
        )
        
        if isDragging {
            return CGPoint(
                x: defaultPosition.x + dragOffset.width,
                y: defaultPosition.y + dragOffset.height
            )
        } else {
            return snapToEdge(in: geometry, from: CGPoint(
                x: defaultPosition.x + dragOffset.width,
                y: defaultPosition.y + dragOffset.height
            ))
        }
    }
    
    private func snapToEdge(in geometry: GeometryProxy, from position: CGPoint) -> CGPoint {
        let margin: CGFloat = 80 // Half width + padding
        let verticalMargin: CGFloat = 100 // Half height + padding
        
        var newPosition = position
        
        // Snap horizontally
        if position.x < geometry.size.width / 2 {
            newPosition.x = margin
        } else {
            newPosition.x = geometry.size.width - margin
        }
        
        // Keep within vertical bounds
        newPosition.y = max(verticalMargin, min(geometry.size.height - verticalMargin, position.y))
        
        return newPosition
    }
    
    // MARK: - Drag Gesture
    
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                isDragging = true
                dragOffset = value.translation
            }
            .onEnded { value in
                isDragging = false
                
                // Update final position
                withAnimation(.spring()) {
                    dragOffset = CGSize(
                        width: dragOffset.width + value.translation.width,
                        height: dragOffset.height + value.translation.height
                    )
                }
            }
    }
}

// MARK: - Live Show Floating Indicator

/// Floating indicator for active live streams
public struct RLiveShowFloatingIndicator: View {
    
    @ObservedObject private var liveShowManager = LiveShowManager.shared
    @Environment(\.colorScheme) private var colorScheme
    
    let position: MiniPlayerPosition
    let onTap: () -> Void
    
    @State private var isPulsing = false
    @State private var isVisible = false
    
    private var adaptiveColors: AdaptiveColors {
        VioColors.adaptive(for: colorScheme)
    }
    
    public init(
        position: MiniPlayerPosition = .topRight,
        onTap: @escaping () -> Void
    ) {
        self.position = position
        self.onTap = onTap
    }
    
    public var body: some View {
        GeometryReader { geometry in
            if liveShowManager.hasActiveLiveStreams && liveShowManager.isIndicatorVisible && !liveShowManager.isWatchingLiveStream {
                indicatorContent
                    .position(indicatorPosition(in: geometry))
                    .scaleEffect(isVisible ? 1.0 : 0.1)
                    .opacity(isVisible ? 1.0 : 0.0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isVisible)
                    .onAppear {
                        withAnimation {
                            isVisible = true
                        }
                        startPulsingAnimation()
                    }
                    .onDisappear {
                        isVisible = false
                    }
            }
        }
        .allowsHitTesting(true)
    }
    
    private var indicatorContent: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                // Live indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 6, height: 6)
                        .scaleEffect(isPulsing ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: isPulsing)
                    
                    Text("LIVE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
                
                // Stream info
                if let featuredStream = liveShowManager.featuredLiveStream {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(featuredStream.streamer.name)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text("\(featuredStream.viewerCount) watching")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                // Dismiss button
                Button(action: {
                    liveShowManager.hideIndicator()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                LinearGradient(
                    colors: [Color.black.opacity(0.8), Color.black.opacity(0.9)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func indicatorPosition(in geometry: GeometryProxy) -> CGPoint {
        let padding: CGFloat = 20
        let indicatorWidth: CGFloat = 140
        let indicatorHeight: CGFloat = 40
        
        switch position {
        case .topLeft:
            return CGPoint(
                x: padding + indicatorWidth/2,
                y: padding + indicatorHeight/2 + 50 // Account for safe area
            )
        case .topRight:
            return CGPoint(
                x: geometry.size.width - padding - indicatorWidth/2,
                y: padding + indicatorHeight/2 + 50 // Account for safe area
            )
        case .bottomLeft:
            return CGPoint(
                x: padding + indicatorWidth/2,
                y: geometry.size.height - padding - indicatorHeight/2 - 100 // Account for safe area
            )
        case .bottomRight:
            return CGPoint(
                x: geometry.size.width - padding - indicatorWidth/2,
                y: geometry.size.height - padding - indicatorHeight/2 - 100 // Account for safe area
            )
        }
    }
    
    private func startPulsingAnimation() {
        withAnimation {
            isPulsing = true
        }
    }
}

// MARK: - Main Live Stream Overlay Container

/// Main container that handles all live stream layouts
public struct RLiveStreamOverlay: View {
    
    @ObservedObject private var liveShowManager = LiveShowManager.shared
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // Full screen overlay
            if liveShowManager.isLiveShowVisible,
               let stream = liveShowManager.currentStream {
                Color.black.ignoresSafeArea()
                
                switch liveShowManager.layout {
                case .fullScreenOverlay:
                    RLiveStreamFullScreenOverlay(stream: stream) {
                        liveShowManager.hideLiveStream()
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    
                case .bottomSheet:
                    Color.black.opacity(0.3).ignoresSafeArea()
                        .onTapGesture {
                            liveShowManager.hideLiveStream()
                        }
                    
                    VStack {
                        Spacer()
                        RLiveStreamBottomSheet(stream: stream) {
                            liveShowManager.hideLiveStream()
                        }
                        .transition(.move(edge: .bottom))
                    }
                    
                case .modal:
                    RLiveStreamModal(stream: stream) {
                        liveShowManager.hideLiveStream()
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            
            // Mini player
            if liveShowManager.isMiniPlayerVisible,
               let stream = liveShowManager.currentStream {
                RLiveMiniPlayer(stream: stream) {
                    liveShowManager.hideLiveStream()
                }
            }
            
            // Floating indicator
            RLiveShowFloatingIndicator(position: liveShowManager.miniPlayerPosition) {
                // Show the featured live stream
                if let featuredStream = liveShowManager.featuredLiveStream {
                    liveShowManager.showLiveStream(featuredStream, layout: .fullScreenOverlay)
                }
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: liveShowManager.isLiveShowVisible)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: liveShowManager.isMiniPlayerVisible)
    }
}
