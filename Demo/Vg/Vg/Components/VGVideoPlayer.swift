import SwiftUI
import AVKit
import AVFoundation
import Combine
import VioCore
import VioUI

struct VGVideoPlayer: View {
    @StateObject private var playerViewModel = VGVideoPlayerViewModel()
    @StateObject private var webSocketManager = WebSocketManager()
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @EnvironmentObject private var cartManager: CartManager
    @State private var isChatExpanded = false
    @State private var showPoll = false
    @State private var showProduct = false
    
    // SDK Client para fetch de productos
    private var sdkClient: SdkClient {
        let config = VioConfiguration.shared
        let baseURL = URL(string: config.environment.graphQLURL)!
        return SdkClient(baseUrl: baseURL, apiKey: config.apiKey)
    }
    
    private var isLandscape: Bool {
        verticalSizeClass == .compact
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let player = playerViewModel.player {
                    CustomVGPlayerView(player: player)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .background(Color.black)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                playerViewModel.showControls.toggle()
                            }
                        }
                } else {
                    Rectangle()
                        .fill(Color.black)
                        .overlay(
                            ProgressView()
                                .tint(.white)
                        )
                }
                
                if playerViewModel.showControls {
                    controlsOverlay
                        .transition(.opacity)
                }
                
                // Chat overlay
                VGChatOverlay(showControls: $playerViewModel.showControls) { expanded in
                    isChatExpanded = expanded
                }
                
                // Product Overlay (sobre el chat y poll)
                if let productEvent = webSocketManager.currentProduct, showProduct {
                    VGProductOverlay(
                        productEvent: productEvent,
                        isChatExpanded: isChatExpanded,
                        sdk: sdkClient,
                        currency: cartManager.currency,
                        country: cartManager.country,
                        onAddToCart: { productDto in
                            if let apiProduct = productDto {
                                print("🛍️ [Product] Agregando producto de la API al carrito: \(apiProduct.title)")
                                let product = convertDtoToProduct(apiProduct)
                                Task {
                                    await cartManager.addProduct(product, quantity: 1)
                                    print("✅ [Product] Producto agregado al carrito")
                                }
                            } else {
                                print("⚠️ [Product] Producto de la API aún no disponible")
                            }
                        },
                        onDismiss: {
                            withAnimation {
                                showProduct = false
                            }
                        }
                    )
                }
                
                // Poll overlay
                if let poll = webSocketManager.currentPoll, showPoll {
                    VGPollOverlay(
                        poll: poll,
                        isChatExpanded: isChatExpanded,
                        onVote: { _ in
                            withAnimation {
                                showPoll = false
                            }
                        },
                        onDismiss: {
                            withAnimation {
                                showPoll = false
                            }
                        }
                    )
                }
            }
            .onAppear {
                playerViewModel.setupPlayer()
                webSocketManager.connect()
            }
            .onDisappear {
                playerViewModel.cleanup()
                webSocketManager.disconnect()
            }
            .onReceive(webSocketManager.$currentProduct) { newProduct in
                print("🎯 [VideoPlayer] Producto recibido: \(newProduct?.name ?? "nil")")
                if newProduct != nil {
                    print("🎯 [VideoPlayer] Mostrando producto")
                    withAnimation {
                        showProduct = true
                    }
                    // Auto-ocultar después de 30 segundos
                    DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                        withAnimation {
                            print("🎯 [VideoPlayer] Ocultando producto")
                            showProduct = false
                        }
                    }
                }
            }
            .onReceive(webSocketManager.$currentPoll) { newPoll in
                print("🎯 [VideoPlayer] Poll recibido: \(newPoll?.question ?? "nil")")
                if newPoll != nil {
                    print("🎯 [VideoPlayer] Mostrando poll")
                    withAnimation { showPoll = true }
                    if let duration = newPoll?.duration {
                        print("🎯 [VideoPlayer] Auto-ocultar en \(duration)s")
                        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(duration)) {
                            withAnimation {
                                print("🎯 [VideoPlayer] Ocultando poll")
                                showPoll = false
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var controlsOverlay: some View {
        GeometryReader { geometry in
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    HStack(spacing: 16) {
                        Button(action: { playerViewModel.rewind() }) {
                            Image(systemName: "gobackward.30")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.white.opacity(0.15))
                                .clipShape(Circle())
                        }
                        
                        Button(action: { playerViewModel.togglePlayPause() }) {
                            Image(systemName: playerViewModel.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(VGTheme.Colors.red)
                                .clipShape(Circle())
                                .shadow(color: VGTheme.Colors.red.opacity(0.6), radius: 8, x: 0, y: 0)
                        }
                        
                        Button(action: { playerViewModel.forward() }) {
                            Image(systemName: "goforward.30")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.white.opacity(0.15))
                                .clipShape(Circle())
                        }
                    }
                    Spacer()
                }
                .padding(.bottom, chatBottomPadding(geometry: geometry))
            }
            .padding(.horizontal, 16)
        }
    }
    
    private func chatBottomPadding(geometry: GeometryProxy) -> CGFloat {
        let chatHeight: CGFloat
        if isChatExpanded {
            // Chat expandido: usar 40% de la altura de la pantalla + padding
            chatHeight = geometry.size.height * 0.4 + 20
        } else {
            // Chat colapsado: altura del handle (40 en landscape, 60 en portrait)
            chatHeight = isLandscape ? 40 : 60
        }
        // Añadir padding adicional para separación
        return chatHeight + 20
    }
    
    // MARK: - Helpers
    
    /// Convierte ProductDto a Product para el CartManager
    private func convertDtoToProduct(_ dto: ProductDto) -> Product {
        let price = convertPrice(dto.price)
        let variants = convertVariants(dto.variants)
        let images = convertImages(dto.images)
        
        let options = dto.options.map {
            Option(id: $0.id, name: $0.name, order: $0.order, values: $0.values)
        }
        
        let categories = dto.categories?.map {
            _Category(id: $0.id, name: $0.name)
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
            product_shipping: nil,
            supplier: dto.supplier,
            supplier_id: dto.supplierId,
            imported_product: dto.importedProduct,
            referral_fee: dto.referralFee,
            options_enabled: dto.optionsEnabled,
            digital: dto.digital,
            origin: dto.origin,
            return: nil
        )
    }
    
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
}

// MARK: - ViewModel

@MainActor
final class VGVideoPlayerViewModel: ObservableObject {
    @Published var player: AVPlayer?
    @Published var isPlaying = false
    @Published var showControls = true
    @Published var isMuted = true
    
    private var timeObserver: Any?
    private var controlsTimer: Timer?
    
    func setupPlayer() {
        if let localVideoPath = Bundle.main.path(forResource: "match", ofType: "mp4") {
            let url = URL(fileURLWithPath: localVideoPath)
            initializePlayer(with: url)
            return
        }
        
        let remote = "https://firebasestorage.googleapis.com/v0/b/tipio-1ec97.appspot.com/o/bar.v.psg.1.ucl.01.10.2025.fullmatchsports.com.1080p.mp4?alt=media&token=593ce8a1-0462-4c37-98c3-e399f25e3853"
        guard let url = URL(string: remote) else { return }
        initializePlayer(with: url)
    }
    
    func cleanup() {
        if let timeObserver = timeObserver, let player = player {
            player.removeTimeObserver(timeObserver)
        }
        controlsTimer?.invalidate()
        player?.pause()
        player = nil
    }
    
    func togglePlayPause() {
        guard let player = player else { return }
        if isPlaying { player.pause() } else { player.play() }
        isPlaying.toggle()
        resetControlsTimer()
    }
    
    func rewind() {
        guard let player = player else { return }
        let current = CMTimeGetSeconds(player.currentTime())
        let newTime = max(current - 30, 0)
        player.seek(to: CMTime(seconds: newTime, preferredTimescale: 1))
        resetControlsTimer()
    }
    
    func forward() {
        guard let player = player else { return }
        let current = CMTimeGetSeconds(player.currentTime())
        let newTime = current + 30
        player.seek(to: CMTime(seconds: newTime, preferredTimescale: 1))
        resetControlsTimer()
    }
    
    private func initializePlayer(with url: URL) {
        player = AVPlayer(url: url)
        player?.allowsExternalPlayback = true
        player?.usesExternalPlaybackWhileExternalScreenIsActive = true
        player?.isMuted = isMuted
        player?.play()
        isPlaying = true
        setupTimeObserver()
        resetControlsTimer()
    }
    
    private func setupTimeObserver() {
        guard let player = player else { return }
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            self.resetControlsTimer()
        }
    }
    
    private func resetControlsTimer() {
        controlsTimer?.invalidate()
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            withAnimation { self?.showControls = false }
        }
    }
}

// MARK: - Player Layer View

struct CustomVGPlayerView: UIViewRepresentable {
    let player: AVPlayer
    
    func makeUIView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        view.backgroundColor = .black
        return view
    }
    
    func updateUIView(_ uiView: PlayerLayerView, context: Context) {}
    
    class PlayerLayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}


