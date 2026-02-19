import SwiftUI
import AVKit
import AVFoundation
import CoreMedia
import WebKit
import VioCore
import VioLiveShow
import VioDesignSystem
import VioUI

#if os(iOS)
import UIKit
#endif

/// Full-screen LiveShow overlay with video player, chat, shopping, and controls
public struct RLiveShowFullScreenOverlay: View {
    
    // MARK: - Properties
    @ObservedObject private var liveShowManager = LiveShowManager.shared
    @EnvironmentObject var cartManager: CartManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var player: AVPlayer?
    @State private var showControls = true
    @State private var controlsTimer: Timer?
    // showShopping removed - now handled by RLiveBottomTabs
    @State private var isLoading = true
    @State private var isPlaying = false
    @State private var isMuted = false // Start unmuted like Alan's approach
    @State private var showPlayPauseIndicator = false
    @State private var selectedProductForDetail: Product?
    @State private var showProductsGrid = false
    
    // Colors based on theme
    private var adaptiveColors: AdaptiveColors {
        VioColors.adaptive(for: colorScheme)
    }
    
    // Current stream
    private var currentStream: LiveStream? {
        liveShowManager.currentStream
    }
    
    public init() {}
    
    // MARK: - Body
    public var body: some View {
        ZStack {
            // Video Player Background
            Color.black
                .ignoresSafeArea()
            
            if let stream = currentStream {
                videoPlayerSection(stream: stream)
                    .ignoresSafeArea()
            } else {
                // No stream placeholder
                noStreamPlaceholder
            }
            
            // Overlay UI
            if let stream = currentStream {
                overlayUI(stream: stream)
            }

            // Dynamic components overlay (renderer)
            DynamicComponentRenderer()
                .zIndex(10_000_000)
            
            // Floating LIVE badge (positioned on the right)
            VStack {
                HStack {
                    Spacer()
                    
                    VStack {
                        AnimatedLiveBadge()
                        Spacer()
                    }
                    .padding(.top, VioSpacing.lg)
                    .padding(.trailing, VioSpacing.lg)
                }
                
                Spacer()
            }
            
            // Bottom content with controls at chat level
            VStack {
                Spacer()
                
                // Controls at chat level (right side)
                HStack {
                    Spacer()
                    
                    rightSideControls
                        .padding(.trailing, VioSpacing.md) // Less margin
                        .padding(.bottom, 160) // Lower position, closer to chat
                }
                
                // Chat component
                RLiveChatComponent()
                    .environmentObject(cartManager)
                
                // Featured products slider (at bottom edge)
                if let stream = currentStream, !stream.featuredProducts.isEmpty {
                    featuredProductsSlider(products: stream.featuredProducts)
                        .onAppear {
                            print("🛍️ [LiveShow] Showing \(stream.featuredProducts.count) products in slider")
                            for product in stream.featuredProducts {
                                print("   - \(product.title): \(product.price.formattedPrice)")
                            }
                        }
                } else {
                    // Debug: Show why no products
                    if let stream = currentStream {
                        Text("No products available (\(stream.featuredProducts.count) products)")
                            .foregroundColor(.red)
                            .padding()
                    }
                }
            }
            
            // Center indicators
            VStack {
                Spacer()
                
                // Play/Pause/Mute indicator (appears temporarily)
                if showPlayPauseIndicator {
                    VStack(spacing: 8) {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.white)
                        
                        // Show mute status
                        Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.2.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    }
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.6))
                            .frame(width: 100, height: 100)
                    )
                    .transition(.scale.combined(with: .opacity))
                }
                
                Spacer()
            }
            
            // Loading indicator
            if isLoading {
                loadingIndicator
            }
            
            // Flying likes component
            RLiveLikesComponent()
        }
        .onAppear {
            print("🎬 [LiveShow] Overlay appeared - starting setup")
            isLoading = true // Start with loading immediately
            showControls = true
            
            // Delay player setup slightly to show loading first
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.setupPlayer()
                if let stream = self.currentStream {
                    self.configurePlayer(with: stream)
                }
            }
        }
        .onDisappear {
            cleanup()
        }
        .sheet(isPresented: $showProductsGrid) {
            RLiveProductsGridOverlay(products: currentStream?.featuredProducts ?? [])
                .environmentObject(cartManager)
        }
        .sheet(item: $selectedProductForDetail) { product in
            VProductDetailOverlay(
                product: product,
                onAddToCart: { product in
                    // Handle add to cart from detail overlay
                    print("🛒 [LiveShow] Adding to cart from detail: \(product.title)")
                    Task {
                        await cartManager.addProduct(product, quantity: 1)
                        print("✅ [LiveShow] Successfully added to cart: \(product.title)")
                    }
                    
                    // Close modal after adding to cart
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        selectedProductForDetail = nil
                    }
                }
            )
            .environmentObject(cartManager)
        }
        // Remove gesture conflicts - keep controls always visible
        // .onTapGesture { toggleControls() }
        .gesture(
            DragGesture(minimumDistance: 100, coordinateSpace: .global)
                .onEnded { value in
                    // Swipe up to minimize to mini-player
                    if value.translation.height < -100 {
                        print("⬆️ [LiveShow] Swipe up detected - minimizing to mini-player")
                        liveShowManager.showMiniPlayer()
                        dismiss()
                    }
                }
        )
    }
    
    // MARK: - Video Player Section
    
    @ViewBuilder
    private func videoPlayerSection(stream: LiveStream) -> some View {
        if currentStream != nil {
            // Use optimized video player with proper URL type detection
            if let videoUrl = stream.videoUrl, !videoUrl.isEmpty {
                // Check URL type and use appropriate player
                if videoUrl.contains("player.vimeo.com") {
                    VimeoWebPlayer(videoUrl: videoUrl)
                } else if videoUrl.contains(".m3u8") || videoUrl.contains("hls") {
                    // HLS stream - try both approaches
                    if let player = player {
                        ZStack {
                            // Try SwiftUI VideoPlayer first (more reliable for HLS)
                            VideoPlayer(player: player)
                                .onAppear {
                                    print("🎬 [LiveShow] SwiftUI VideoPlayer appeared")
                                }
                            
                            // Fallback: Custom player with debugging
                            // CustomVideoPlayer(player: player)
                            
                            // Debug overlay to verify video is showing
                            VStack {
                                HStack {
                                    Text("HLS Video Playing")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.green.opacity(0.8))
                                        .cornerRadius(4)
                                    Spacer()
                                }
                                Spacer()
                            }
                            .padding(.top, 50)
                            .padding(.leading, 20)
                        }
                    } else {
                        // Fallback for HLS
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                VStack {
                                    Text("Loading HLS Stream...")
                                        .foregroundColor(.white)
                                    VCustomLoader(style: .rotate, size: 40, color: .white)
                                }
                            )
                    }
                } else if let player = player {
                    // Direct video URL - use AVPlayer
                    CustomVideoPlayer(player: player)
                } else {
                    // Fallback
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Text("Video not available")
                                .foregroundColor(.white)
                        )
                }
            } else {
                // Si no hay videoUrl, muestra "Coming soon"
                ZStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                    Text("Coming soon")
                        .font(.title)
                        .foregroundColor(.white)
                        .bold()
                }
            }
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
        }
    }
    
    // MARK: - Overlay UI
    
    @ViewBuilder
    private func overlayUI(stream: LiveStream) -> some View {
        VStack(spacing: 0) {
            // Top overlay (controls, close button, stream info)
            topOverlay(stream: stream)
            
            Spacer()
            
            // Bottom overlay removed - now using product banner and chat separately
        }
        // Always show controls - no fade in/out
        .opacity(1)
    }
    
    // MARK: - Top Overlay
    
    @ViewBuilder
    private func topOverlay(stream: LiveStream) -> some View {
        VStack(spacing: 0) {
            // Top gradient
            LinearGradient(
                colors: [Color.black.opacity(0.7), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 120)
            .overlay(
                topControlsContent(stream: stream),
                alignment: .top
            )
        }
    }
    
    @ViewBuilder
    private func topControlsContent(stream: LiveStream) -> some View {
        HStack(alignment: .top, spacing: VioSpacing.md) {
            // Left side - Close button (small)
            VStack {
                Button(action: {
                    liveShowManager.hideLiveStream()
                    dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(Color.black.opacity(0.5))
                        )
                }
                
                Spacer()
            }
            
            // Center - Stream info with avatar
            VStack(alignment: .center, spacing: VioSpacing.xs) {
                // Avatar + Title
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
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text("by \(stream.streamer.name)")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                // Viewer count
                if liveShowManager.currentViewerCount > 0 {
                    HStack(spacing: VioSpacing.xs) {
                        Image(systemName: "eye.fill")
                            .font(.caption2)
                        Text("\(liveShowManager.currentViewerCount)")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, VioSpacing.sm)
                    .padding(.vertical, VioSpacing.xs)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(VioBorderRadius.small)
                }
            }
            
            Spacer()
            
            // This will be moved to bottom - removing from top
        }
        .padding(.horizontal, VioSpacing.md) // Less padding to move controls towards center
        .padding(.top, VioSpacing.lg)
    }
    
    // MARK: - Bottom Overlay
    
    @ViewBuilder
    private func bottomOverlay(stream: LiveStream) -> some View {
        VStack(spacing: 0) {
            // Bottom gradient
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 300)
            .overlay(
                bottomControlsContent(stream: stream),
                alignment: .bottom
            )
        }
    }
    
    @ViewBuilder
    private func bottomControlsContent(stream: LiveStream) -> some View {
        VStack(spacing: VioSpacing.md) {
            // Connection status only (tabs handle chat/shopping)
            HStack {
                Spacer()
                
                // Connection status
                if liveShowManager.isConnectedToTipio {
                    HStack(spacing: VioSpacing.xs) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Text("Tipio Connected")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.horizontal, VioSpacing.sm)
                    .padding(.vertical, VioSpacing.xs)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(VioBorderRadius.small)
                }
            }
        }
        .padding(.horizontal, VioSpacing.lg)
        .padding(.bottom, VioSpacing.xl)
    }
    
    // MARK: - Featured Products Slider
    
    @ViewBuilder
    private func featuredProductsSlider(products: [LiveProduct]) -> some View {
        GeometryReader { geometry in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: VioSpacing.sm) {
                    ForEach(products) { liveProduct in
                        // Use the horizontal card we had before (was perfect)
                        liveProductHorizontalCard(product: liveProduct)
                            .frame(width: geometry.size.width - 32) // Full width minus small margins
                    }
                }
                .padding(.horizontal, VioSpacing.md) // Small margins on sides
            }
        }
        .frame(height: 80) // Compact height for bottom placement
    }
    
    // MARK: - Live Product Horizontal Card (perfect version)
    
    @ViewBuilder
    private func liveProductHorizontalCard(product: LiveProduct) -> some View {
        HStack(spacing: VioSpacing.md) {
            // Product image (60x60 like before)
            AsyncImage(url: URL(string: product.imageUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
            }
            .frame(width: 60, height: 60)
            .cornerRadius(8)
            .clipped()
            
            // Product info (matching previous perfect layout)
            VStack(alignment: .leading, spacing: 4) {
                Text(product.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text("COSMED BEAUTY")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                    .lineLimit(1)
                
                // Price row (red price + strikethrough) - uses amount_incl_taxes and compare_at_incl_taxes if available
                HStack(spacing: VioSpacing.xs) {
                    Text(product.price.formattedPrice)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.red)
                    
                    if let originalPrice = product.originalPrice,
                       let compareAtPrice = originalPrice.formattedCompareAtPrice {
                        Text(compareAtPrice)
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                            .strikethrough()
                    }
                }
            }
            
            Spacer()
            
            // Red dot indicator (exactly like before)
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
        }
        .padding(.horizontal, VioSpacing.md)
        .padding(.vertical, VioSpacing.sm)
        .background(Color.black.opacity(0.85))
        .onTapGesture {
            // Open product detail overlay for variant selection
            print("🛍️ [LiveShow] Opening product detail for: \(product.title)")
            selectedProductForDetail = product.asProduct
        }
    }
    
    // MARK: - Placeholders
    
    @ViewBuilder
    private var noStreamPlaceholder: some View {
        VStack(spacing: VioSpacing.lg) {
            Image(systemName: "video.slash")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            Text("No Live Stream Available")
                .font(VioTypography.title1)
                .foregroundColor(.white)
            
            Text("Please check back later or try connecting to Tipio.")
                .font(VioTypography.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            Button("Close") {
                dismiss()
            }
            .foregroundColor(adaptiveColors.primary)
        }
        .padding(VioSpacing.xl)
    }
    
    @ViewBuilder
    private var loadingIndicator: some View {
        VStack(spacing: VioSpacing.lg) {
            // Animated loading indicator
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 4)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(Color.white, lineWidth: 4)
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isLoading)
            }
            
            VStack(spacing: VioSpacing.sm) {
                Text("Loading Vimeo Stream...")
                    .font(VioTypography.headline)
                    .foregroundColor(.white)
                
                Text("Please wait while the video loads")
                    .font(VioTypography.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(VioSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: VioBorderRadius.large)
                .fill(Color.black.opacity(0.85))
                .shadow(radius: 20)
        )
        .frame(maxWidth: 280)
    }
    
    // MARK: - Helper Methods

    private func monitorPlayerStatus(_ item: AVPlayerItem) {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            print("📊 [LiveShow] Player status: \(item.status.description)")
            
            // Log additional HLS debugging info
            if let url = item.asset as? AVURLAsset {
                print("🔗 [LiveShow] Asset URL: \(url.url.absoluteString)")
                if url.url.absoluteString.contains(".m3u8") {
                    print("📺 [LiveShow] HLS stream detected")
                }
            }
            
            if item.status == .readyToPlay {
                print("✅ [LiveShow] Player is ready to play")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                timer.invalidate()
            } else if item.status == .failed {
                let errorMsg = item.error?.localizedDescription ?? "Unknown error"
                print("❌ [LiveShow] Player failed: \(errorMsg)")
                
                // Enhanced error detection for HLS
                var shouldRefresh = false
                var isHLSError = false
                
                if let error = item.error as NSError? {
                    print("🔍 [LiveShow] Error details:")
                    print("   - Domain: \(error.domain)")
                    print("   - Code: \(error.code)")
                    print("   - UserInfo: \(error.userInfo)")
                    
                    // Check for HTTP response errors
                    if error.domain == NSURLErrorDomain {
                        if let response = error.userInfo["NSErrorFailingURLResponseKey"] as? HTTPURLResponse {
                            print("   - HTTP Status: \(response.statusCode)")
                            if response.statusCode == 403 {
                                shouldRefresh = true
                                isHLSError = true
                            }
                        }
                    }
                    
                    // Check for HLS-specific errors
                    if errorMsg.lowercased().contains("hls") || 
                       errorMsg.lowercased().contains("m3u8") ||
                       errorMsg.lowercased().contains("playlist") {
                        isHLSError = true
                    }
                }
                
                // Fallback: si el mensaje contiene "permission" o "403"
                if errorMsg.lowercased().contains("permission") || 
                   errorMsg.contains("403") ||
                   errorMsg.lowercased().contains("forbidden") {
                    shouldRefresh = true
                    isHLSError = true
                }
                
                timer.invalidate()
                
                if shouldRefresh && isHLSError, let stream = self.currentStream {
                    print("🔄 [LiveShow] HLS token expired or permission denied, refreshing HLS URL...")
                    refreshHLSAndRetry(streamId: stream.id)
                    return
                }
                
                // Try fallback for non-HLS errors or if refresh fails
                DispatchQueue.main.async {
                    print("🔄 [LiveShow] Trying fallback video...")
                    self.setupPlayerWithFallback()
                }
            }
        }
    }

    /// Calls the refresh endpoint and retries playback
    private func refreshHLSAndRetry(streamId: String) {
        print("🔄 [LiveShow] Starting HLS refresh for stream ID: \(streamId)")
        isLoading = true
        
        let urlString = "https://stg-dev-microservices.tipioapp.com/api/stg/livestreams/refresh-hls/sdk/\(streamId)"
        guard let url = URL(string: urlString) else {
            print("❌ [LiveShow] Invalid refresh HLS URL: \(urlString)")
            DispatchQueue.main.async { self.isLoading = false }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30.0
        
        // Add headers if needed
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("VioSDK/1.0", forHTTPHeaderField: "User-Agent")
        
        print("📡 [LiveShow] Making refresh request to: \(urlString)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ [LiveShow] Failed to refresh HLS: \(error.localizedDescription)")
                    self.isLoading = false
                    // Try fallback after refresh failure
                    self.setupPlayerWithFallback()
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ [LiveShow] Invalid response type")
                    self.isLoading = false
                    self.setupPlayerWithFallback()
                    return
                }
                
                print("📊 [LiveShow] Refresh response status: \(httpResponse.statusCode)")
                
                guard httpResponse.statusCode == 200 else {
                    print("❌ [LiveShow] Refresh failed with status: \(httpResponse.statusCode)")
                    self.isLoading = false
                    self.setupPlayerWithFallback()
                    return
                }
                
                guard let data = data else {
                    print("❌ [LiveShow] No data from refresh HLS")
                    self.isLoading = false
                    self.setupPlayerWithFallback()
                    return
                }
                
                do {
                    // Decodifica el objeto stream actualizado
                    let decoder = JSONDecoder()
                    let refreshedTipioStream = try decoder.decode(TipioLiveStream.self, from: data)
                    let refreshedStream = refreshedTipioStream.toLiveStream()
                    
                    print("✅ [LiveShow] Successfully refreshed stream")
                    print("🔗 [LiveShow] New video URL: \(refreshedStream.videoUrl ?? "nil")")
                    
                    // Actualiza el stream y reintenta setupPlayer
                    self.liveShowManager.updateCurrentStream(refreshedStream)
                    self.setupPlayer()
                } catch {
                    print("❌ [LiveShow] Failed to decode refreshed stream: \(error.localizedDescription)")
                    self.isLoading = false
                    self.setupPlayerWithFallback()
                }
            }
        }.resume()
    }
    
    private func setupPlayer() {
        guard let stream = currentStream else { 
            print("❌ [LiveShow] No current stream for setup")
            return 
        }
        
        print("🎬 [LiveShow] Setting up player for stream: \(stream.title)")
        print("🎬 [LiveShow] Stream URL: \(stream.videoUrl ?? "nil")")
        
        guard let videoUrl = stream.videoUrl, !videoUrl.isEmpty else {
            print("❌ [LiveShow] Stream has no video URL")
            isLoading = false
            return
        }

        print("🔗 [LiveShow] Final video URL: \(videoUrl)")
        
        // Detect URL type for better logging
        if videoUrl.contains(".m3u8") {
            print("📺 [LiveShow] HLS stream detected (.m3u8)")
        } else if videoUrl.contains("player.vimeo.com") {
            print("🎥 [LiveShow] Vimeo player URL detected")
        } else if videoUrl.contains("hls") {
            print("📺 [LiveShow] HLS stream detected (hls keyword)")
        } else {
            print("🎬 [LiveShow] Direct video URL detected")
        }

        guard let url = URL(string: videoUrl) else {
            print("❌ [LiveShow] Failed to create URL from: \(videoUrl)")
            isLoading = false
            return
        }
        
        print("📱 [LiveShow] Creating AVPlayer with URL...")
        player = AVPlayer(url: url)
        
        guard let player = player else {
            print("❌ [LiveShow] Failed to create AVPlayer")
            isLoading = false
            return
        }
        
        print("⚙️ [LiveShow] Configuring player settings...")
        
        // Configure for better streaming experience
        // For HLS streams, we want to minimize stalling
        if videoUrl.contains(".m3u8") || videoUrl.contains("hls") {
            print("🎬 [LiveShow] Configuring for HLS stream")
            player.automaticallyWaitsToMinimizeStalling = true // Better for HLS
            
            // For live streams, seek to the end (live position)
            if stream.isLive {
                print("🔴 [LiveShow] Live stream detected - seeking to live position")
                seekToLivePosition()
            }
        } else {
            player.automaticallyWaitsToMinimizeStalling = false // Better for direct videos
        }
        
        player.isMuted = false // Start unmuted for HLS streams (Alan's approach)
        player.allowsExternalPlayback = false // Prevent fullscreen takeover
        
        // Configure audio session for live streaming
        configureAudioSession()
        
        // Alternative: Force audio without session configuration
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.forceAudioWithoutSession()
        }
        
        // Check audio status for debugging
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.checkAudioStatus()
        }
        
        // Simple audio check after delay (Alan's approach)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.checkAudioStatus()
        }
        
        // Additional HLS-specific configuration
        if let currentItem = player.currentItem {
            // Enable HLS optimizations for live streaming
            currentItem.preferredForwardBufferDuration = 3.0 // Shorter buffer for live streams
            currentItem.canUseNetworkResourcesForLiveStreamingWhilePaused = true
            
            // For live streams, configure to minimize latency
            if stream.isLive {
                currentItem.preferredPeakBitRate = 0 // Use highest available bitrate
                currentItem.preferredMaximumResolution = CGSize(width: 1920, height: 1080) // Max resolution
            }
        }
        
        // Monitor player status (minimal logging)
        player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 5, preferredTimescale: 1), queue: .main) { time in
            let currentTime = CMTimeGetSeconds(time)
            if Int(currentTime) % 30 == 0 { // Log every 30 seconds to reduce spam
                print("⏱️ [LiveShow] Video time: \(currentTime)s")
            }
        }
        
        // Monitor player item status
        if let currentItem = player.currentItem {
            print("📋 [LiveShow] Player item status: \(currentItem.status)")
            
            // Monitor status changes without KVO
            monitorPlayerStatus(currentItem)
        }
        
        print("▶️ [LiveShow] Starting playback...")
        
        // Auto-play
        player.play()
        isPlaying = true
        
        isLoading = false
        print("✅ [LiveShow] Player setup complete")
        
        // For live streams, try to seek to live position after a longer delay
        if stream.isLive {
            print("🔴 [LiveShow] Live stream detected - will seek to live position in 5 seconds")
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                self.seekToLivePosition()
            }
            
            // Also try after 10 seconds as backup
            DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                self.seekToLivePosition()
            }
            
            // For HLS streams, try a different approach after 15 seconds
            if stream.videoUrl?.contains(".m3u8") == true || stream.videoUrl?.contains("hls") == true {
                DispatchQueue.main.asyncAfter(deadline: .now() + 15.0) {
                    self.forceSeekToLiveForHLS()
                }
            }
        }
        
        // Check status after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if let item = self.player?.currentItem {
                print("🔍 [LiveShow] Status check after 3s:")
                print("   - Player item status: \(item.status)")
                print("   - Is playing: \(self.player?.rate != 0)")
                print("   - Error: \(item.error?.localizedDescription ?? "None")")
                
                if item.status == .failed {
                    print("❌ [LiveShow] Player failed")
                    
                    // For live streams, don't use fallback - show error instead
                    if stream.isLive {
                        print("🔴 [LiveShow] Live stream failed - not using fallback")
                        // You could show an error message here instead of fallback
                        self.showStreamError()
                    } else {
                        print("🔄 [LiveShow] Non-live stream failed, trying fallback URL...")
                        self.setupPlayerWithFallback()
                    }
                }
            }
        }
    }
    
    private func showStreamError() {
        print("🔴 [LiveShow] Showing stream error - live stream unavailable")
        // You could set a state variable here to show an error UI
        // For now, just log the error
        isLoading = false
    }
    
    private func setupPlayerWithFallback() {
        print("🔄 [LiveShow] Setting up player with fallback URL...")
        
        let fallbackUrl = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4"
        
        guard let url = URL(string: fallbackUrl) else {
            print("❌ [LiveShow] Failed to create fallback URL")
            return
        }
        
        player = AVPlayer(url: url)
        player?.automaticallyWaitsToMinimizeStalling = false
        player?.isMuted = true
        player?.allowsExternalPlayback = false
        player?.play()
        isPlaying = true
        
        print("✅ [LiveShow] Fallback player setup complete with: \(fallbackUrl)")
    }
    
    // private func monitorPlayerStatus(_ item: AVPlayerItem) {
    //     // Check status periodically instead of using KVO
    //     Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
    //         print("📊 [LiveShow] Player status: \(item.status.description)")
            
    //         if item.status == .readyToPlay {
    //             print("✅ [LiveShow] Player is ready to play")
    //             timer.invalidate()
    //         } else if item.status == .failed {
    //             print("❌ [LiveShow] Player failed: \(item.error?.localizedDescription ?? "Unknown error")")
    //             timer.invalidate()
                
    //             // Try fallback
    //             DispatchQueue.main.async {
    //                 self.setupPlayerWithFallback()
    //             }
    //         }
    //     }
    // }
    
    private func configurePlayer(with stream: LiveStream) {
        // Configure player for live streaming
        if stream.isLive {
            player?.automaticallyWaitsToMinimizeStalling = false
        }
        
        // Set initial state
        player?.isMuted = isMuted
        isPlaying = player?.rate != 0
        
        // Monitor playback state
        player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: 600), queue: .main) { _ in
            self.isPlaying = self.player?.rate != 0
        }
    }
    
    private func togglePlayPause() {
        guard let player = player else { return }
        
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        
        // Show temporary play/pause indicator
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showPlayPauseIndicator = true
        }
        
        // Hide indicator after 1 second
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 0.3)) {
                showPlayPauseIndicator = false
            }
        }
    }
    
    private func toggleMute() {
        guard let player = player else { 
            print("❌ [LiveShow] No player available for mute toggle")
            return 
        }
        
        isMuted.toggle()
        player.isMuted = isMuted
        
        print("🔊 [LiveShow] Mute toggled: \(isMuted ? "MUTED" : "UNMUTED")")
        
        // Configure audio session when unmuting
        if !isMuted {
            configureAudioSession()
        }
        
        // Show temporary mute indicator
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showPlayPauseIndicator = true
        }
        
        // Hide indicator after 1 second
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 0.3)) {
                showPlayPauseIndicator = false
            }
        }
        
        // Haptic feedback
        #if os(iOS)
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        #endif
    }
    
    private func toggleControls() {
        showControls.toggle()
        if showControls {
            startControlsTimer()
        } else {
            controlsTimer?.invalidate()
        }
    }
    
    private func startControlsTimer() {
        controlsTimer?.invalidate()
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
            withAnimation {
                showControls = false
            }
        }
    }
    
    /// Seek to live position for live streams
    private func seekToLivePosition() {
        guard let player = player else { 
            print("❌ [LiveShow] No player available for live seek")
            return 
        }
        
        print("🔴 [LiveShow] Attempting to seek to live position...")
        
        // For live streams, we want to seek to the end (live position)
        // This is especially important for HLS streams
        if let currentItem = player.currentItem {
            let duration = currentItem.duration
            
            // Check if duration is valid and not indefinite
            if duration.isValid && !duration.isIndefinite {
                let durationSeconds = CMTimeGetSeconds(duration)
                print("🔴 [LiveShow] Stream duration: \(durationSeconds)s")
                
                // Only seek to live if this is actually a live stream (long duration)
                // Short durations (< 60s) are likely fallback videos, not live streams
                if durationSeconds > 60 {
                    // Try multiple strategies to get to live position
                    self.tryMultipleSeekStrategies(duration: duration, player: player)
                } else {
                    // Short duration - likely fallback video, just play from start
                    print("⚠️ [LiveShow] Short duration detected (\(durationSeconds)s) - likely fallback video, playing from start")
                    player.play()
                }
            } else {
                // For indefinite duration (live streams), just start playing
                print("🔴 [LiveShow] Live stream with indefinite duration - starting playback")
                player.play()
            }
        } else {
            // Fallback: just start playing
            print("🔴 [LiveShow] No current item - starting playback")
            player.play()
        }
    }
    
    /// Try multiple seek strategies to get to live position
    private func tryMultipleSeekStrategies(duration: CMTime, player: AVPlayer) {
        let durationSeconds = CMTimeGetSeconds(duration)
        
        // Strategy 1: Seek to 5 seconds before the end
        let liveTime1 = CMTimeSubtract(duration, CMTime(seconds: 5, preferredTimescale: 1))
        let liveTime1Seconds = CMTimeGetSeconds(liveTime1)
        print("🔴 [LiveShow] Strategy 1: Seeking to \(liveTime1Seconds)s (5s before end)")
        
        player.seek(to: liveTime1, toleranceBefore: .zero, toleranceAfter: .zero) { completed in
            if completed {
                print("✅ [LiveShow] Strategy 1 successful - seeked to live position")
                player.play()
            } else {
                print("⚠️ [LiveShow] Strategy 1 failed, trying strategy 2...")
                self.tryStrategy2(duration: duration, player: player)
            }
        }
    }
    
    /// Strategy 2: Seek to 10 seconds before the end
    private func tryStrategy2(duration: CMTime, player: AVPlayer) {
        let liveTime2 = CMTimeSubtract(duration, CMTime(seconds: 10, preferredTimescale: 1))
        let liveTime2Seconds = CMTimeGetSeconds(liveTime2)
        print("🔴 [LiveShow] Strategy 2: Seeking to \(liveTime2Seconds)s (10s before end)")
        
        player.seek(to: liveTime2, toleranceBefore: .zero, toleranceAfter: .zero) { completed in
            if completed {
                print("✅ [LiveShow] Strategy 2 successful - seeked to live position")
                player.play()
            } else {
                print("⚠️ [LiveShow] Strategy 2 failed, trying strategy 3...")
                self.tryStrategy3(duration: duration, player: player)
            }
        }
    }
    
    /// Strategy 3: Seek to 90% of duration
    private func tryStrategy3(duration: CMTime, player: AVPlayer) {
        let durationSeconds = CMTimeGetSeconds(duration)
        let liveTime3 = CMTime(seconds: durationSeconds * 0.9, preferredTimescale: 1)
        let liveTime3Seconds = CMTimeGetSeconds(liveTime3)
        print("🔴 [LiveShow] Strategy 3: Seeking to \(liveTime3Seconds)s (90% of duration)")
        
        player.seek(to: liveTime3, toleranceBefore: .zero, toleranceAfter: .zero) { completed in
            if completed {
                print("✅ [LiveShow] Strategy 3 successful - seeked to live position")
                player.play()
            } else {
                print("❌ [LiveShow] All strategies failed - playing from current position")
                player.play()
            }
        }
    }
    
    /// Force seek to live for HLS streams using a different approach
    private func forceSeekToLiveForHLS() {
        guard let player = player else { 
            print("❌ [LiveShow] No player available for HLS live seek")
            return 
        }
        
        print("🔴 [LiveShow] Force seeking to live for HLS stream...")
        
        // For HLS streams, try to seek to a very large time (beyond the end)
        // This should automatically snap to the live position
        let veryLargeTime = CMTime(seconds: 999999, preferredTimescale: 1)
        
        player.seek(to: veryLargeTime, toleranceBefore: .zero, toleranceAfter: .zero) { completed in
            if completed {
                print("✅ [LiveShow] HLS force seek successful - should be at live position")
                player.play()
            } else {
                print("⚠️ [LiveShow] HLS force seek failed, trying alternative...")
                // Alternative: seek to current time + 30 seconds
                let currentTime = player.currentTime()
                let futureTime = CMTimeAdd(currentTime, CMTime(seconds: 30, preferredTimescale: 1))
                player.seek(to: futureTime) { completed in
                    if completed {
                        print("✅ [LiveShow] Alternative HLS seek successful")
                        player.play()
                    } else {
                        print("❌ [LiveShow] All HLS seek attempts failed")
                        player.play()
                    }
                }
            }
        }
    }
    
    /// Configure audio session for live streaming (robust approach)
    private func configureAudioSession() {
        #if os(iOS)
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // First try to deactivate to avoid conflicts
            try? audioSession.setActive(false)
            
            // Wait a moment before reconfiguring
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                do {
                    // Try basic playback category first
                    try audioSession.setCategory(.playback)
                    try audioSession.setActive(true)
                    print("🔊 [LiveShow] Audio session configured (basic playback)")
                } catch {
                    print("❌ [LiveShow] Basic audio session failed: \(error)")
                    
                    // Try fallback with different options
                    do {
                        try audioSession.setCategory(.playback, mode: .default, options: [])
                        try audioSession.setActive(true)
                        print("🔊 [LiveShow] Audio session configured (fallback)")
                    } catch {
                        print("❌ [LiveShow] Fallback audio session also failed: \(error)")
                    }
                }
            }
        } catch {
            print("❌ [LiveShow] Initial audio session setup failed: \(error)")
        }
        #endif
    }
    
    /// Check and log audio status for debugging
    private func checkAudioStatus() {
        guard let player = player else { return }
        
        print("🔊 [LiveShow] Audio Status Check:")
        print("   - Player muted: \(player.isMuted)")
        print("   - Player volume: \(player.volume)")
        print("   - Player rate: \(player.rate)")
        
        #if os(iOS)
        let audioSession = AVAudioSession.sharedInstance()
        print("   - Audio session category: \(audioSession.category)")
        print("   - Audio session mode: \(audioSession.mode)")
        print("   - Audio session is active: \(audioSession.isOtherAudioPlaying)")
        #endif
    }
    
    /// Force audio playback by toggling mute state
    private func forceAudioPlayback() {
        guard let player = player else { return }
        
        print("🔊 [LiveShow] Forcing audio playback...")
        
        // Force unmute and reconfigure audio
        player.isMuted = false
        isMuted = false
        
        // Set volume to maximum
        player.volume = 1.0
        
        // Reconfigure audio session
        configureAudioSession()
        
        // Try to pause and play to reset audio
        player.pause()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            player.play()
        }
        
        // Check status after forcing
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.checkAudioStatus()
        }
        
        print("🔊 [LiveShow] Audio forced - should be unmuted now")
    }
    
    /// Try alternative audio approach for problematic streams
    private func tryAlternativeAudioApproach() {
        guard let player = player else { return }
        
        print("🔊 [LiveShow] Trying alternative audio approach...")
        
        #if os(iOS)
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // Try different audio session configuration
            try audioSession.setActive(false)
            try audioSession.setCategory(.playback, mode: .default, options: [.allowBluetooth, .allowBluetoothA2DP])
            try audioSession.setActive(true)
            
            // Force player settings
            player.isMuted = false
            player.volume = 1.0
            
            // Try to seek to current position to trigger audio
            let currentTime = player.currentTime()
            player.seek(to: currentTime) { completed in
                if completed {
                    print("✅ [LiveShow] Alternative audio approach completed")
                } else {
                    print("⚠️ [LiveShow] Alternative audio approach failed")
                }
            }
            
            print("🔊 [LiveShow] Alternative audio session configured")
        } catch {
            print("❌ [LiveShow] Alternative audio approach failed: \(error)")
        }
        #endif
    }
    
    /// Force audio without relying on audio session configuration
    private func forceAudioWithoutSession() {
        guard let player = player else { return }
        
        print("🔊 [LiveShow] Forcing audio without session configuration...")
        
        // Force player settings
        player.isMuted = false
        player.volume = 1.0
        isMuted = false
        
        // Try to pause and play to reset audio
        player.pause()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            player.play()
        }
        
        // Check if audio is working
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.checkAudioStatus()
        }
        
        print("🔊 [LiveShow] Audio forced without session - should work now")
    }
    
    // handleSwipeGesture removed - now handled inline to reduce gesture conflicts
    
    private func addProductToCartWithFeedback(_ liveProduct: LiveProduct) {
        liveShowManager.addProductToCart(liveProduct, cartManager: cartManager)
        
        // Show visual feedback
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            // Could add some visual feedback here
        }
        
        print("🛒 [LiveShow] Added to cart: \(liveProduct.title)")
    }
    
    // sendChatMessage removed - now handled by RLiveChatComponent
    
    private func shareStream(_ stream: LiveStream) {
        // Implement sharing functionality
        print("📤 [LiveShow] Sharing stream: \(stream.title)")
    }
    
    private func createUserLike() {
        // Efecto local inmediato
        LiveLikesManager.shared.createUserLike()
        // Notificar backend HEART
        if let stream = liveShowManager.currentStream {
            LiveShowManager.shared.sendHeartForCurrentStream(isVideoLive: stream.isLive)
        }
        
        // Haptic feedback
        #if os(iOS)
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        #endif
    }
    
    private func cleanup() {
        player?.pause()
        controlsTimer?.invalidate()
    }
    
    // MARK: - Right Side Controls
    
    @ViewBuilder
    private var rightSideControls: some View {
        VStack(spacing: VioSpacing.md) {
            // Play/Pause button
            Button(action: togglePlayPause) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.4))
                            .background(
                                Circle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    )
            }
            
            // Mute/Unmute button
            Button(action: toggleMute) {
                Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.2.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.4))
                            .background(
                                Circle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    )
            }
            
            // Products grid button
            Button(action: {
                showProductsGrid = true
            }) {
                Image(systemName: "grid")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.4))
                            .background(
                                Circle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    )
            }
            
            // Cart button with badge
            Button(action: {
                print("🛒 [LiveShow] Opening cart overlay")
                cartManager.isCheckoutPresented = true
            }) {
                ZStack {
                    Image(systemName: "bag.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(Color.black.opacity(0.4))
                                .background(
                                    Circle()
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                    
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
            
            // Likes button
            Button(action: {
                createUserLike()
            }) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.red)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.4))
                            .background(
                                Circle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    )
            }
        }
    }
}

// MARK: - Custom Video Player

#if os(iOS)
/// Vimeo WebView player that works with player.vimeo.com URLs
struct VimeoWebPlayer: UIViewRepresentable {
    let videoUrl: String  
    func makeUIView(context: Context) -> WKWebView {
        print("🎬 [LiveShow] Creating Vimeo WebView player with URL: \(videoUrl)")
        
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.suppressesIncrementalRendering = true
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.backgroundColor = UIColor.black
        webView.isOpaque = false
        webView.navigationDelegate = context.coordinator
        
        // Reduce gesture conflicts
        webView.allowsBackForwardNavigationGestures = false
        
        context.coordinator.webView = webView
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        print("🎬 [VimeoWebPlayer] makeUIView called with videoUrl: \(videoUrl)")
        // Only load if not already loaded
        if webView.url == nil {
            print("🔗 [LiveShow] Loading Vimeo HTML...")
            let html = createVimeoHTML()
            webView.loadHTMLString(html, baseURL: URL(string: "https://player.vimeo.com"))
        }
    }
    
    private func createVimeoHTML() -> String {
        // Extract video ID from URL
        let videoId = videoUrl.components(separatedBy: "/").last ?? "1029631656"
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                body, html {
                    margin: 0;
                    padding: 0;
                    height: 100vh;
                    width: 100vw;
                    background-color: #000000;
                    overflow: hidden;
                }
                .video-container {
                    position: relative;
                    width: 100%;
                    height: 100vh;
                    overflow: hidden;
                }
                iframe {
                    position: absolute;
                    top: 50%;
                    left: 50%;
                    width: 120%;
                    height: 120%;
                    transform: translate(-50%, -50%);
                    border: none;
                    object-fit: cover;
                }
            </style>
        </head>
        <body>
            <div class="video-container">
                <iframe src="https://player.vimeo.com/video/\(videoId)?badge=0&autopause=0&autoplay=1&muted=1&controls=0&title=0&byline=0&portrait=0&background=1"
                        frameborder="0"
                        allow="autoplay; fullscreen; picture-in-picture"
                        allowfullscreen>
                </iframe>
            </div>
            
            <script>
                // Minimal JavaScript to reduce processing
                console.log('🎬 Vimeo loaded');
            </script>
        </body>
        </html>
        """
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var webView: WKWebView?
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("✅ [LiveShow] Vimeo WebView navigation finished")
            
            // Wait for iframe to load, then send notification
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                NotificationCenter.default.post(name: .vimeoPlayerLoaded, object: nil)
                print("📺 [LiveShow] Posted Vimeo player loaded notification")
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("❌ [LiveShow] Vimeo WebView failed: \(error.localizedDescription)")
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            print("🔄 [LiveShow] Vimeo WebView started loading")
        }
    }
}

/// Custom video player for direct video URLs (non-Vimeo)
struct CustomVideoPlayer: UIViewRepresentable {
    let player: AVPlayer
    
    func makeUIView(context: Context) -> UIView {
        print("🎬 [CustomVideoPlayer] Creating video player view")
        
        let view = UIView()
        view.backgroundColor = UIColor.red // Temporary red background to see the view bounds
        
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.backgroundColor = UIColor.blue.cgColor // Temporary blue background to see the layer
        
        // IMPORTANT: Prevent fullscreen by disabling certain player controls
        playerLayer.player?.allowsExternalPlayback = false
        
        view.layer.addSublayer(playerLayer)
        
        // Store layer reference for updates
        context.coordinator.playerLayer = playerLayer
        context.coordinator.containerView = view
        
        print("🎬 [CustomVideoPlayer] Player layer created and added to view")
        print("🎬 [CustomVideoPlayer] Initial view bounds: \(view.bounds)")
        print("🎬 [CustomVideoPlayer] Initial layer frame: \(playerLayer.frame)")
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update layer frame when view bounds change
        if let playerLayer = context.coordinator.playerLayer {
            let newFrame = uiView.bounds
            print("🎬 [CustomVideoPlayer] Updating frame to: \(newFrame)")
            
            DispatchQueue.main.async {
                playerLayer.frame = newFrame
                print("🎬 [CustomVideoPlayer] Frame updated successfully")
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var playerLayer: AVPlayerLayer?
        var containerView: UIView?
        private var frameUpdateTimer: Timer?
        
        init() {
            // Set up frame update timer to ensure proper sizing
            frameUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.updateFrameIfNeeded()
            }
        }
        
        deinit {
            frameUpdateTimer?.invalidate()
        }
        
        private func updateFrameIfNeeded() {
            guard let playerLayer = playerLayer,
                  let containerView = containerView else { return }
            
            let currentFrame = playerLayer.frame
            let targetFrame = containerView.bounds
            
            // Debug logging
            if targetFrame.width > 0 && targetFrame.height > 0 {
                print("🎬 [CustomVideoPlayer] Frame check - Current: \(currentFrame), Target: \(targetFrame)")
            }
            
            // Force update if target frame has valid dimensions
            if targetFrame.width > 0 && targetFrame.height > 0 {
                DispatchQueue.main.async {
                    playerLayer.frame = targetFrame
                    print("🎬 [CustomVideoPlayer] Frame force-updated to: \(targetFrame)")
                    
                    // Additional debugging
                    print("🎬 [CustomVideoPlayer] Layer bounds after update: \(playerLayer.bounds)")
                    print("🎬 [CustomVideoPlayer] Layer position: \(playerLayer.position)")
                    print("🎬 [CustomVideoPlayer] Layer anchorPoint: \(playerLayer.anchorPoint)")
                }
            }
        }
    }
}
#else
/// Fallback video player for non-iOS platforms
struct VimeoWebPlayer: View {
    let videoUrl: String
    
    var body: some View {
        // Simple fallback for non-iOS
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .overlay(
                Text("Video: \(videoUrl)")
                    .foregroundColor(.white)
            )
    }
}

struct CustomVideoPlayer: View {
    let player: AVPlayer
    
    var body: some View {
        VideoPlayer(player: player)
    }
}
#endif

// MARK: - Animated LIVE Badge

struct AnimatedLiveBadge: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 6) {
            // Pulsating red dot (only the dot animates)
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .scaleEffect(isAnimating ? 1.4 : 1.0)
                .opacity(isAnimating ? 0.6 : 1.0)
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
            
            Text("LIVE")
                .font(.caption.weight(.bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, VioSpacing.sm)
        .padding(.vertical, VioSpacing.xs)
        .background(Color.black.opacity(0.6))
        .cornerRadius(VioBorderRadius.small)
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Preview

#Preview {
    RLiveShowFullScreenOverlay()
        .environmentObject(CartManager())
}

// MARK: - Notification Names

extension Notification.Name {
    static let vimeoPlayerLoaded = Notification.Name("vimeoPlayerLoaded")
}

// MARK: - Extensions for Debugging

extension AVPlayer.Status: CustomStringConvertible {
    public var description: String {
        switch self {
        case .unknown: return "unknown"
        case .readyToPlay: return "readyToPlay"
        case .failed: return "failed"
        @unknown default: return "unknown default"
        }
    }
}

extension AVPlayerItem.Status: CustomStringConvertible {
    public var description: String {
        switch self {
        case .unknown: return "unknown"
        case .readyToPlay: return "readyToPlay"  
        case .failed: return "failed"
        @unknown default: return "unknown default"
        }
    }
}
