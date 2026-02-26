import SwiftUI
import AVKit
import VioCore
import VioLiveShow
import VioDesignSystem
import VioUI

/// Modular and configurable LiveShow overlay component
public struct VLiveShowOverlay: View {
    
    // MARK: - Configuration
    private let configuration: VLiveShowConfiguration
    private let stream: LiveStream
    private let onDismiss: () -> Void
    
    // MARK: - Environment
    @EnvironmentObject private var cartManager: CartManager
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - State
    @State private var player: AVPlayer?
    @State private var isLoading = true
    @State private var isPlaying = false
    @State private var isMuted = true
    @State private var selectedProduct: Product?
    @State private var showProductsGrid = false
    
    // MARK: - Computed Properties
    private var colors: VLiveShowConfiguration.Colors {
        configuration.colors
    }
    
    private var layout: VLiveShowConfiguration.Layout {
        configuration.layout
    }
    
    private var typography: VLiveShowConfiguration.Typography {
        configuration.typography
    }
    
    private var spacing: VLiveShowConfiguration.Spacing {
        configuration.spacing
    }
    
    // MARK: - Initializer
    public init(
        stream: LiveStream,
        configuration: VLiveShowConfiguration = .default,
        onDismiss: @escaping () -> Void = {}
    ) {
        self.stream = stream
        self.configuration = configuration
        self.onDismiss = onDismiss
    }
    
    // MARK: - Body
    public var body: some View {
        ZStack {
            // Video background
            videoPlayerSection
            
            // Overlay background
            colors.overlayBackground
                .ignoresSafeArea()
            
            // Content layers
            contentLayers

            // Dynamic components overlay (non-intrusivo)
            DynamicComponentRenderer()
                .zIndex(10_000_000)
            
            // Loading indicator
            if isLoading {
                loadingIndicator
            }
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            cleanup()
        }
        .sheet(isPresented: $showProductsGrid) {
            if layout.showProducts {
                VLiveProductsGridOverlay(products: stream.featuredProducts)
                    .environmentObject(cartManager)
            }
        }
        .sheet(item: $selectedProduct) { product in
            VProductDetailOverlay(product: product, onAddToCart: { product in
                Task {
                    await cartManager.addProduct(product, quantity: 1)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    selectedProduct = nil
                }
            })
            .environmentObject(cartManager)
        }
    }
    
    // MARK: - Content Layers
    
    @ViewBuilder
    private var contentLayers: some View {
        VStack {
            // Top layer
            topContentLayer
            
            Spacer()
            
            // Bottom layer
            bottomContentLayer
        }
        
        // Side controls
        if layout.showControls {
            sideControlsLayer
        }
        
        // Live badge
        if layout.showLiveBadge {
            liveBadgeLayer
        }
        
        // Likes overlay
        if layout.showLikes {
            VLiveLikesComponent()
        }
    }
    
    // MARK: - Top Content Layer
    
    @ViewBuilder
    private var topContentLayer: some View {
        HStack {
            // Close button
            if layout.showCloseButton {
                closeButton
            }
            
            Spacer()
            
            // Stream info
            streamInfoSection
            
            Spacer()
        }
        .padding(.horizontal, spacing.contentPadding)
        .padding(.top, spacing.contentPadding)
    }
    
    @ViewBuilder
    private var closeButton: some View {
        Button(action: onDismiss) {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(colors.controlsTint)
                .frame(width: 28, height: 28)
                .background(colors.controlsBackground)
                .clipShape(Circle())
        }
    }
    
    @ViewBuilder
    private var streamInfoSection: some View {
        VStack(spacing: 4) {
            HStack(spacing: VioSpacing.sm) {
                // Streamer avatar
                AsyncImage(url: URL(string: stream.streamer.avatarUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 28, height: 28)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(stream.title)
                        .font(.system(size: typography.streamTitleSize, weight: .semibold))
                        .foregroundColor(colors.controlsTint)
                        .lineLimit(1)
                    
                    Text("by \(stream.streamer.name)")
                        .font(.system(size: typography.streamSubtitleSize))
                        .foregroundColor(colors.controlsTint.opacity(0.8))
                }
            }
            
            // Viewer count
            if stream.viewerCount > 0 {
                HStack(spacing: VioSpacing.xs) {
                    Image(systemName: "eye.fill")
                        .font(.caption2)
                    Text("\(stream.viewerCount)")
                        .font(.caption)
                }
                .foregroundColor(colors.controlsTint)
                .padding(.horizontal, VioSpacing.sm)
                .padding(.vertical, VioSpacing.xs)
                .background(colors.controlsBackground)
                .cornerRadius(VioBorderRadius.small)
            }
        }
    }
    
    // MARK: - Bottom Content Layer
    
    @ViewBuilder
    private var bottomContentLayer: some View {
        VStack(spacing: 0) {
            // Chat component
            if layout.showChat {
                VLiveChatComponent()
                    .environmentObject(cartManager)
            }
            
            // Products slider
            if layout.showProducts && !stream.featuredProducts.isEmpty {
                productsSliderSection
            }
        }
    }
    
    @ViewBuilder
    private var productsSliderSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: spacing.productSpacing) {
                ForEach(stream.featuredProducts) { product in
                    VLiveProductCard(product: product)
                        .frame(width: 300)
                        .environmentObject(cartManager)
                        .onTapGesture {
                            selectedProduct = product.asProduct
                        }
                }
            }
            .padding(.horizontal, spacing.contentPadding)
        }
        .frame(height: 80)
        .background(colors.productsBackground)
    }
    
    // MARK: - Side Controls Layer
    
    @ViewBuilder
    private var sideControlsLayer: some View {
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
                VStack(spacing: spacing.controlsSpacing) {
                    // Play/Pause
                    controlButton(
                        icon: isPlaying ? "pause.fill" : "play.fill",
                        action: togglePlayPause
                    )
                    
                    // Mute
                    controlButton(
                        icon: isMuted ? "speaker.slash.fill" : "speaker.2.fill",
                        action: toggleMute
                    )
                    
                    // Products grid
                    if layout.showProducts {
                        controlButton(
                            icon: "grid",
                            action: { showProductsGrid = true }
                        )
                    }
                    
                    // Cart
                    cartButton
                    
                    // Likes
                    if layout.showLikes {
                        controlButton(
                            icon: "heart.fill",
                            color: .red,
                            action: {
                                // Efecto local inmediato
                                createUserLike()
                                // Notificar backend HEART
                                LiveShowManager.shared.sendHeartForCurrentStream(isVideoLive: stream.isLive)
                            }
                        )
                    }
                }
                .padding(.trailing, spacing.contentPadding)
                .padding(.bottom, 160)
            }
        }
    }
    
    @ViewBuilder
    private func controlButton(
        icon: String,
        color: Color? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(color ?? colors.controlsTint)
                .frame(width: 44, height: 44)
                .background(colors.controlsBackground)
                .overlay(
                    Circle()
                        .stroke(colors.controlsStroke, lineWidth: 1)
                )
                .clipShape(Circle())
        }
    }
    
    @ViewBuilder
    private var cartButton: some View {
        Button(action: { cartManager.isCheckoutPresented = true }) {
            ZStack {
                Image(systemName: "bag.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(colors.controlsTint)
                    .frame(width: 44, height: 44)
                    .background(colors.controlsBackground)
                    .overlay(
                        Circle()
                            .stroke(colors.controlsStroke, lineWidth: 1)
                    )
                    .clipShape(Circle())
                
                // Cart badge
                if !cartManager.items.isEmpty {
                    Text("\(cartManager.items.count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(.red))
                        .offset(x: 15, y: -15)
                }
            }
        }
    }
    
    // MARK: - Live Badge Layer
    
    @ViewBuilder
    private var liveBadgeLayer: some View {
        VStack {
            HStack {
                Spacer()
                
                AnimatedLiveBadge()
                    .padding(.top, spacing.contentPadding)
                    .padding(.trailing, spacing.contentPadding)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Video Player Section
    
    @ViewBuilder
    private var videoPlayerSection: some View {
        if let player = player {
            CustomVideoPlayer(player: player)
                .ignoresSafeArea()
        } else {
            // Thumbnail placeholder
            AsyncImage(url: URL(string: stream.thumbnailUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
            }
            .ignoresSafeArea()
        }
    }
    
    // MARK: - Loading Indicator
    
    @ViewBuilder
    private var loadingIndicator: some View {
        VStack(spacing: VioSpacing.lg) {
            VCustomLoader(style: .rotate, size: 48, color: colors.controlsTint, speed: 1.2)
            
            Text("Loading stream...")
                .font(.system(size: typography.streamSubtitleSize))
                .foregroundColor(colors.controlsTint)
        }
        .padding(spacing.contentPadding * 2)
        .background(colors.controlsBackground)
        .cornerRadius(VioBorderRadius.large)
    }
    
    // MARK: - Actions
    
    private func setupPlayer() {
        let demoVideoUrl = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4"
        
        guard let url = URL(string: demoVideoUrl) else {
            isLoading = false
            return
        }
        
        player = AVPlayer(url: url)
        player?.automaticallyWaitsToMinimizeStalling = false
        player?.isMuted = true
        player?.allowsExternalPlayback = false
        player?.play()
        
        isPlaying = true
        isLoading = false
    }
    
    private func togglePlayPause() {
        guard let player = player else { return }
        
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }
    
    private func toggleMute() {
        guard let player = player else { return }
        
        isMuted.toggle()
        player.isMuted = isMuted
    }
    
    private func createUserLike() {
        LiveLikesManager.shared.createUserLike()
        
        #if os(iOS)
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        #endif
    }
    
    private func cleanup() {
        player?.pause()
        player = nil
    }
}

// AnimatedLiveBadge removed - using existing one from VLiveShowFullScreenOverlay

// MARK: - Usage Examples and Presets

extension VLiveShowOverlay {
    
    /// Minimal LiveShow overlay with basic functionality
    public static func minimal(
        stream: LiveStream,
        onDismiss: @escaping () -> Void = {}
    ) -> some View {
        VLiveShowOverlay(
            stream: stream,
            configuration: .minimal,
            onDismiss: onDismiss
        )
    }
    
    /// Dark theme LiveShow overlay for streaming apps
    public static func darkTheme(
        stream: LiveStream,
        onDismiss: @escaping () -> Void = {}
    ) -> some View {
        VLiveShowOverlay(
            stream: stream,
            configuration: .adaptive(for: SwiftUI.ColorScheme.dark),
            onDismiss: onDismiss
        )
    }
    
    /// Custom configured LiveShow overlay
    public static func custom(
        stream: LiveStream,
        colors: VLiveShowConfiguration.Colors? = nil,
        typography: VLiveShowConfiguration.Typography? = nil,
        spacing: VLiveShowConfiguration.Spacing? = nil,
        onDismiss: @escaping () -> Void = {}
    ) -> some View {
        let config = VLiveShowConfiguration(
            colors: colors ?? .default,
            typography: typography ?? .default,
            spacing: spacing ?? .default
        )
        
        return VLiveShowOverlay(
            stream: stream,
            configuration: config,
            onDismiss: onDismiss
        )
    }
}

// MARK: - Preview

#Preview {
    if let stream = LiveShowManager.shared.activeStreams.first {
        VLiveShowOverlay(stream: stream)
            .environmentObject(CartManager())
    } else {
        Text("No stream available")
    }
}
