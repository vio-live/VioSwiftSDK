import SwiftUI
import AVKit
import AVFoundation
import Combine
import VioCore
import VioUI

/// TV2 Video Player with casting support
/// Simulates a live streaming experience with AirPlay/Chromecast capability
struct TV2VideoPlayer: View {
    let match: Match
    let onDismiss: () -> Void
    
    @StateObject private var playerViewModel = VideoPlayerViewModel()
    // Legacy WebSocketManager removed — SDK (CampaignManager) handles WS for campaign events.
    // Keeping state vars typed to legacy structs so overlays compile while migration completes.
    @State private var currentPoll: PollEventData? = nil
    @State private var currentProduct: ProductEventData? = nil
    @State private var currentContest: ContestEventData? = nil
    @EnvironmentObject private var cartManager: CartManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var isChatExpanded = false
    @State private var showPoll = false
    @State private var showProduct = false
    @State private var showContest = false
    @State private var showCheckout = false
    @State private var isLoadingVideo = true
    
    // SDK Client para fetch de productos
    private var sdkClient: SdkClient {
        let config = VioConfiguration.shared
        let baseURL = URL(string: config.environment.graphQLURL)!
        return SdkClient(baseUrl: baseURL, apiKey: config.apiKey)
    }
    
    // Detect landscape orientation
    private var isLandscape: Bool {
        verticalSizeClass == .compact
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Video Player Layer (adjusts to 60% when chat is expanded)
                VStack(spacing: 0) {
                    ZStack {
                        if let player = playerViewModel.player {
                            CustomVideoPlayerView(player: player)
                                .aspectRatio(16/9, contentMode: .fit)
                                .onTapGesture {
                                    playerViewModel.toggleControlsVisibility()
                                }
                                .onAppear {
                                    // Hide loader when video appears
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        isLoadingVideo = false
                                    }
                                }
                        }
                        
                        // Loading overlay
                        if isLoadingVideo {
                            ZStack {
                                Color.black.opacity(0.9)
                                
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: TV2Theme.Colors.primary))
                                    .scaleEffect(2.0)
                            }
                            .transition(.opacity)
                        }
                    }
                    .frame(height: isChatExpanded ? geometry.size.height * 0.6 : geometry.size.height)
                    .background(Color.black)
                    
                    if isChatExpanded {
                        Spacer()
                    }
                }
                .ignoresSafeArea()
            
            // Overlay Controls
            if playerViewModel.showControls {
                VStack {
                    // Top Bar
                    topBar
                    
                    Spacer()
                    
                    // Bottom Controls
                    bottomControls
                }
                .transition(.opacity)
            }
            
            // Live Badge (compact, near top edge)
            VStack {
                HStack {
                    Spacer()
                    
                    liveBadge
                        .padding(.top, isLandscape ? TV2Theme.Spacing.sm : TV2Theme.Spacing.lg)
                        .padding(.trailing, TV2Theme.Spacing.sm)
                }
                
                Spacer()
            }
            
            // Contest Overlay (máxima prioridad)
            if let contest = currentContest, showContest {
                TV2ContestOverlay(
                    contest: contest,
                    isChatExpanded: isChatExpanded,
                    onJoin: {
                        print("🎁 [Contest] Usuario se unió: \(contest.name)")
                        // Aquí se enviará la participación al servidor después
                    },
                    onDismiss: {
                        withAnimation {
                            showContest = false
                        }
                    }
                )
            }
            
            // Product Overlay (sobre el chat y poll)
            if let productEvent = currentProduct, showProduct {
                TV2ProductOverlay(
                    productEvent: productEvent,
                    isChatExpanded: isChatExpanded,
                    sdk: sdkClient,
                    currency: cartManager.currency,
                    country: cartManager.country,
                    onAddToCart: { productDto in
                        if let apiProduct = productDto {
                            print("🛍️ [Product] Agregando producto de la API al carrito: \(apiProduct.title)")
                            // Convertir ProductDto a Product para el CartManager
                            let product = convertDtoToProduct(apiProduct)
                            Task {
                                await cartManager.addProduct(product, quantity: 1)
                                print("✅ [Product] Producto agregado al carrito")
                            }
                        } else {
                            print("⚠️ [Product] Producto de la API aún no disponible, usando fallback: \(productEvent.name)")
                            // El producto de la API aún no ha cargado, no hacer nada o usar fallback
                        }
                    },
                    onDismiss: {
                        withAnimation {
                            showProduct = false
                        }
                    }
                )
            }
            
            // Poll Overlay (sobre el chat)
            if let poll = currentPoll, showPoll {
                TV2PollOverlay(
                    poll: poll,
                    isChatExpanded: isChatExpanded,
                    onVote: { option in
                        print("📊 [Poll] Votado: \(option)")
                        // Aquí se enviará el voto al servidor después
                    },
                    onDismiss: {
                        withAnimation {
                            showPoll = false
                        }
                    }
                )
            }
            
            // Chat Overlay (Twitch/Kick style sliding panel)
            TV2ChatOverlay(
                showControls: $playerViewModel.showControls,
                onExpandedChange: { expanded in
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        isChatExpanded = expanded
                    }
                }
            )
            
            // Floating cart indicator - SIEMPRE visible en el video player
            VFloatingCartIndicator(
                customPadding: EdgeInsets(
                    top: 0,
                    leading: 0,
                    bottom: 100,
                    trailing: TV2Theme.Spacing.md
                ),
                onTap: {
                    showCheckout = true
                }
            )
            .zIndex(1000) // Por encima de todo en el video player
            }
        }
        .sheet(isPresented: $showCheckout) {
            VCheckoutOverlay()
                .environmentObject(cartManager)
        }
        .preferredColorScheme(.dark)
        .statusBar(hidden: true) // Hide status bar for immersive experience
        .persistentSystemOverlays(.hidden) // Hide home indicator in landscape
        .ignoresSafeArea() // Full screen
        .onAppear {
            playerViewModel.setupPlayer()
            // Enable all orientations for video playback
            setOrientation(.allButUpsideDown)
            
            // 🎯 SDK: discoverCampaigns → WS identify → cart_intent → notificación
            // Legacy WebSocketManager.connect() removed — was opening a 2nd WS to the same endpoint
            Task {
                print("🎯 [TV2VideoPlayer] Starting SDK campaign discovery...")
                await CampaignManager.shared.discoverCampaigns(broadcastId: nil)
                print("🎯 [TV2VideoPlayer] SDK campaigns: \(CampaignManager.shared.activeCampaigns.count), connected: \(CampaignManager.shared.isConnected)")
            }
        }
        .onDisappear {
            playerViewModel.cleanup()
            // Return to portrait when dismissed
            setOrientation(.portrait)
            // Legacy webSocketManager.disconnect() removed — no longer needed
        }
        // Note: poll/product/contest overlays are kept but won't trigger until
        // SDK emits those event types via CampaignWebSocketManager callbacks.
    }
    
    // MARK: - Helpers
    
    /// Convierte PriceDto a Price
    private func convertPrice(_ priceDto: PriceDto) -> Price {
        return Price(
            amount: Float(priceDto.amount),
            currency_code: priceDto.currencyCode,
            amount_incl_taxes: priceDto.amountInclTaxes.map { Float($0) },
            tax_amount: priceDto.taxAmount.map { Float($0) },
            tax_rate: priceDto.taxRate.map { Float($0) },
            compare_at: priceDto.compareAt.map { Float($0) },
            compare_at_incl_taxes: priceDto.compareAtInclTaxes.map { Float($0) }
        )
    }
    
    /// Convierte ProductImageDto a ProductImage
    private func convertImages(_ imageDtos: [ProductImageDto]) -> [ProductImage] {
        return imageDtos.map { 
            ProductImage(
                id: $0.id, 
                url: $0.url, 
                width: $0.width, 
                height: $0.height, 
                order: $0.order ?? 0
            ) 
        }
    }
    
    /// Convierte VariantDto a Variant
    private func convertVariants(_ variantDtos: [VariantDto]) -> [Variant] {
        return variantDtos.map { variantDto in
            Variant(
                id: variantDto.id,
                barcode: variantDto.barcode,
                price: convertPrice(variantDto.price),
                quantity: variantDto.quantity,
                sku: variantDto.sku,
                title: variantDto.title,
                images: convertImages(variantDto.images)
            )
        }
    }
    
    /// Convierte ProductDto a Product para el CartManager
    private func convertDtoToProduct(_ dto: ProductDto) -> Product {
        let price = convertPrice(dto.price)
        let variants = convertVariants(dto.variants)
        let images = convertImages(dto.images)
        
        let options = dto.options.map { 
            Option(
                id: $0.id, 
                name: $0.name, 
                order: $0.order, 
                values: $0.values  // Ya es String, no array
            ) 
        }
        
        let categories = dto.categories?.map { 
            _Category(id: $0.id, name: $0.name) 
        }
        
        let shipping = dto.productShipping?.map { s in
            ProductShipping(
                id: s.id,
                name: s.name,
                description: s.description,
                custom_price_enabled: s.customPriceEnabled,
                default: s.defaultOption,
                shipping_country: s.shippingCountry?.map { sc in
                    ShippingCountry(
                        id: sc.id,
                        country: sc.country,
                        price: BasePrice(
                            amount: Float(sc.price.amount),
                            currency_code: sc.price.currencyCode,
                            amount_incl_taxes: sc.price.amountInclTaxes.map { Float($0) },
                            tax_amount: sc.price.taxAmount.map { Float($0) },
                            tax_rate: sc.price.taxRate.map { Float($0) }
                        )
                    )
                }
            )
        }
        
        let returnInfo = dto.returnInfo.map { r in
            ReturnInfo(
                return_right: r.returnRight,
                return_label: r.returnLabel,
                return_cost: r.returnCost.map { Float($0) },
                supplier_policy: r.supplierPolicy,
                return_address: r.returnAddress.map { ra in
                    ReturnAddress(
                        same_as_business: ra.sameAsBusiness,
                        same_as_warehouse: ra.sameAsWarehouse,
                        country: ra.country,
                        timezone: ra.timezone,
                        address: ra.address,
                        address_2: ra.address2,
                        post_code: ra.postCode,
                        return_city: ra.returnCity
                    )
                }
            )
        }
        
        return Product(
            id: dto.id,
            title: dto.title,
            brand: dto.brand,
            description: dto.description,
            tags: dto.tags,
            sku: dto.sku,
            quantity: dto.quantity,
            price: price,
            variants: variants,
            barcode: dto.barcode,
            options: options,
            categories: categories,
            images: images,
            product_shipping: shipping,
            supplier: dto.supplier,
            supplier_id: dto.supplierId,
            imported_product: dto.importedProduct,
            referral_fee: dto.referralFee,
            options_enabled: dto.optionsEnabled,
            digital: dto.digital,
            origin: dto.origin,
            return: returnInfo
        )
    }
    
    // MARK: - Orientation Helper
    private func setOrientation(_ orientation: UIInterfaceOrientationMask) {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: orientation))
        }
        UINavigationController.attemptRotationToDeviceOrientation()
    }
    
    // MARK: - Top Bar
    private var topBar: some View {
        HStack(spacing: TV2Theme.Spacing.md) {
            // Back Button - TV2 styled
            Button(action: {
                dismiss()
                onDismiss()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: isLandscape ? 16 : 18, weight: .bold))
                    if !isLandscape {
                        Text("Tilbake")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, isLandscape ? 10 : 14)
                .padding(.vertical, isLandscape ? 7 : 10)
                .background(TV2Theme.Colors.primary.opacity(0.9))
                .clipShape(Capsule())
            }
            
            // Title
            if !isLandscape {
                VStack(alignment: .leading, spacing: 2) {
                    Text(match.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(match.subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.8))
                }
            } else {
                Text(match.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Mute Button
            Button(action: { playerViewModel.toggleMute() }) {
                Image(systemName: playerViewModel.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: isLandscape ? 14 : 16))
                    .foregroundColor(.white)
                    .frame(width: isLandscape ? 32 : 36, height: isLandscape ? 32 : 36)
                    .background(Color.white.opacity(0.25))
                    .clipShape(Circle())
            }
            
            // Cast Button (AirPlay)
            AirPlayButton()
                .frame(width: isLandscape ? 32 : 36, height: isLandscape ? 32 : 36)
        }
        .padding(.horizontal, TV2Theme.Spacing.md)
        .padding(.top, isLandscape ? TV2Theme.Spacing.sm : 45)
        .background(
            LinearGradient(
                colors: [
                    Color.black.opacity(0.8),
                    Color.black.opacity(0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: isLandscape ? 80 : 130)
        )
    }
    
    // MARK: - Bottom Controls
    private var bottomControls: some View {
        VStack(spacing: isLandscape ? TV2Theme.Spacing.sm : TV2Theme.Spacing.md) {
            // Progress Bar with Scrubbing
            VStack(spacing: isLandscape ? 3 : 6) {
                HStack {
                    Text(playerViewModel.currentTimeText)
                        .font(.system(size: isLandscape ? 11 : 13, weight: .semibold))
                        .foregroundColor(.white)
                        .monospacedDigit()
                    
                    Spacer()
                    
                    // Live Indicator or Duration
                    Text(playerViewModel.durationText)
                        .font(.system(size: isLandscape ? 11 : 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .monospacedDigit()
                }
                
                // Progress Slider
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background Track
                        Capsule()
                            .fill(Color.white.opacity(0.3))
                            .frame(height: isLandscape ? 4 : 5)
                        
                        // Progress Fill
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [TV2Theme.Colors.primary, TV2Theme.Colors.secondary],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: geometry.size.width * playerViewModel.progress,
                                height: isLandscape ? 4 : 5
                            )
                        
                        // Scrubber Handle
                        Circle()
                            .fill(TV2Theme.Colors.primary)
                            .frame(width: isLandscape ? 12 : 14, height: isLandscape ? 12 : 14)
                            .shadow(color: TV2Theme.Colors.primary.opacity(0.5), radius: 3, x: 0, y: 0)
                            .offset(x: (geometry.size.width * playerViewModel.progress) - (isLandscape ? 6 : 7))
                    }
                }
                .frame(height: isLandscape ? 12 : 14)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let screenWidth = UIScreen.main.bounds.width - (TV2Theme.Spacing.md * 2)
                            let progress = max(0, min(1, value.location.x / screenWidth))
                            playerViewModel.seek(to: progress)
                        }
                )
            }
            
            // Main Playback Controls
            HStack(spacing: isLandscape ? TV2Theme.Spacing.lg : TV2Theme.Spacing.xl) {
                // Rewind 10s
                ControlButton(
                    icon: "gobackward.10",
                    size: isLandscape ? 20 : 24,
                    color: TV2Theme.Colors.primary,
                    action: { playerViewModel.skipBackward(seconds: 10) }
                )
                
                Spacer()
                
                // Play/Pause (Center Button)
                Button(action: { playerViewModel.togglePlayPause() }) {
                    ZStack {
                        Circle()
                            .fill(TV2Theme.Colors.primary.opacity(0.9))
                            .frame(width: isLandscape ? 50 : 60, height: isLandscape ? 50 : 60)
                        
                        Image(systemName: playerViewModel.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: isLandscape ? 22 : 26, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                Spacer()
                
                // Forward 10s
                ControlButton(
                    icon: "goforward.10",
                    size: isLandscape ? 20 : 24,
                    color: TV2Theme.Colors.primary,
                    action: { playerViewModel.forward() }
                )
            }
            .padding(.horizontal, TV2Theme.Spacing.lg)
            
            // Secondary Controls Area (reserved for future content)
            HStack {
                // TODO: Add additional controls here as needed
                // This space is reserved for future functionality
                Spacer()
            }
            .frame(height: isLandscape ? 36 : 44)
            .padding(.horizontal, TV2Theme.Spacing.md)
            .padding(.bottom, isLandscape ? TV2Theme.Spacing.xs : TV2Theme.Spacing.sm)
        }
        .padding(.horizontal, TV2Theme.Spacing.md)
        .padding(.bottom, isLandscape ? TV2Theme.Spacing.md : TV2Theme.Spacing.xl)
        .background(
            LinearGradient(
                colors: [
                    Color.black.opacity(0),
                    Color.black.opacity(0.85)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: isLandscape ? 150 : 220)
        )
    }
    
    // MARK: - Live Badge
    private var liveBadge: some View {
        HStack(spacing: isLandscape ? 4 : 5) {
            Circle()
                .fill(Color.white)
                .frame(width: isLandscape ? 6 : 7, height: isLandscape ? 6 : 7)
            
            Text("DIREKTE")
                .font(.system(size: isLandscape ? 10 : 11, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, isLandscape ? 8 : 10)
        .padding(.vertical, isLandscape ? 4 : 5)
        .background(
            Capsule()
                .fill(Color.red.opacity(0.95))
        )
        .shadow(color: Color.black.opacity(0.4), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Control Button Component
struct ControlButton: View {
    let icon: String
    let size: CGFloat
    var color: Color = .white
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 40, height: 40)
        }
    }
}

// MARK: - View Model
@MainActor
class VideoPlayerViewModel: ObservableObject {
    @Published var player: AVPlayer?
    @Published var isPlaying = false
    @Published var showControls = true
    @Published var progress: Double = 0
    @Published var currentTimeText = "00:00"
    @Published var durationText = "2:10:48"
    @Published var isMuted = true
    @Published var playbackSpeed: Float = 1.0
    
    private var timeObserver: Any?
    private var controlsTimer: Timer?
    
    func setupPlayer() {
        // Priority 1: Try local video file (if included in bundle)
        if let localVideoPath = Bundle.main.path(forResource: "match", ofType: "mp4") {
            let url = URL(fileURLWithPath: localVideoPath)
            print("🎥 [VideoPlayer] Using local video: match.mp4")
            initializePlayer(with: url)
            return
        }
        
        // Priority 2: Load from Firebase Storage (remote video)
        // This video is hosted on Firebase Storage and works perfectly with AVPlayer
        print("🌐 [VideoPlayer] Loading video from Firebase Storage...")
        
        let firebaseVideoURL = "https://storage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
        
        guard let videoURL = URL(string: firebaseVideoURL) else {
            print("❌ [VideoPlayer] Invalid Firebase URL")
            return
        }
        
        print("✅ [VideoPlayer] Firebase video URL ready")
        initializePlayer(with: videoURL)
    }
    
    private func initializePlayer(with url: URL) {
        print("▶️ [VideoPlayer] Initializing player...")
        
        player = AVPlayer(url: url)
        player?.allowsExternalPlayback = true // Enable AirPlay
        player?.usesExternalPlaybackWhileExternalScreenIsActive = true
        player?.isMuted = isMuted
        
        // Start playing
        player?.play()
        isPlaying = true
        
        // Setup time observer
        setupTimeObserver()
        
        // Auto-hide controls
        resetControlsTimer()
    }
    
    private func setupTimeObserver() {
        guard let player = player else { return }
        
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            
            let currentTime = CMTimeGetSeconds(time)
            let duration = CMTimeGetSeconds(player.currentItem?.duration ?? .zero)
            
            if duration.isFinite && duration > 0 {
                self.progress = currentTime / duration
                self.currentTimeText = self.formatTime(currentTime)
                self.durationText = self.formatTime(duration)
            }
        }
    }
    
    func togglePlayPause() {
        guard let player = player else { return }
        
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
        resetControlsTimer()
    }
    
    func rewind() {
        guard let player = player else { return }
        let currentTime = CMTimeGetSeconds(player.currentTime())
        let newTime = max(currentTime - 30, 0)
        player.seek(to: CMTime(seconds: newTime, preferredTimescale: 1))
        resetControlsTimer()
    }
    
    func forward() {
        guard let player = player else { return }
        let currentTime = CMTimeGetSeconds(player.currentTime())
        let duration = CMTimeGetSeconds(player.currentItem?.duration ?? .zero)
        let newTime = min(currentTime + 30, duration)
        player.seek(to: CMTime(seconds: newTime, preferredTimescale: 1))
        resetControlsTimer()
    }
    
    func skipBackward(seconds: Double) {
        guard let player = player else { return }
        let currentTime = CMTimeGetSeconds(player.currentTime())
        let newTime = max(currentTime - seconds, 0)
        player.seek(to: CMTime(seconds: newTime, preferredTimescale: 1))
        resetControlsTimer()
    }
    
    func toggleMute() {
        guard let player = player else { return }
        isMuted.toggle()
        player.isMuted = isMuted
        resetControlsTimer()
    }
    
    func setSpeed(_ speed: Float) {
        guard let player = player else { return }
        playbackSpeed = speed
        player.rate = speed
        if isPlaying {
            player.play()
        }
        resetControlsTimer()
    }
    
    func seek(to progress: Double) {
        guard let player = player,
              let duration = player.currentItem?.duration else { return }
        
        let seconds = CMTimeGetSeconds(duration) * progress
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 1))
        resetControlsTimer()
    }
    
    func toggleControlsVisibility() {
        withAnimation {
            showControls.toggle()
        }
        
        if showControls {
            resetControlsTimer()
        }
    }
    
    private func resetControlsTimer() {
        controlsTimer?.invalidate()
        
        withAnimation {
            showControls = true
        }
        
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            withAnimation {
                self?.showControls = false
            }
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "00:00" }
        
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }
    
    func cleanup() {
        player?.pause()
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
        controlsTimer?.invalidate()
    }
}

// MARK: - AirPlay Button Wrapper
struct AirPlayButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let routePickerView = AVRoutePickerView()
        routePickerView.backgroundColor = .clear
        routePickerView.tintColor = .white
        routePickerView.activeTintColor = .white
        return routePickerView
    }
    
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        // No update needed
    }
}

// MARK: - Custom Video Player View (No Native Controls)
struct CustomVideoPlayerView: UIViewRepresentable {
    let player: AVPlayer
    
    func makeUIView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.playerLayer.player = player
        // Use fill to cover entire screen including edges in landscape
        view.playerLayer.videoGravity = .resizeAspectFill
        view.backgroundColor = .black
        return view
    }
    
    func updateUIView(_ uiView: PlayerLayerView, context: Context) {
        // Layer updates automatically via layoutSubviews
    }
    
    class PlayerLayerView: UIView {
        override class var layerClass: AnyClass {
            return AVPlayerLayer.self
        }
        
        var playerLayer: AVPlayerLayer {
            return layer as! AVPlayerLayer
        }
    }
}

// MARK: - Preview
#Preview {
    TV2VideoPlayer(
        match: Match.dortmundAtletico,
        onDismiss: {}
    )
}

