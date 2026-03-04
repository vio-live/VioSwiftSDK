//
//  VCastingVideoPlayer.swift
//  Viaplay
//
//  Created by Angelo Sepulveda on 27/10/2025.
//

import SwiftUI
import VioDesignSystem
import AVKit
import AVFoundation
import Combine
import VioCore
import VioUI
import VioEngagementUI
import VioEngagementSystem

/// Viaplay Video Player with casting support
/// Simulates a live streaming experience with AirPlay/Chromecast capability
public struct VCastingVideoPlayer: View {
    let match: Match
    let onDismiss: () -> Void
    let onNavigateToNextCastingContest: (() -> Void)?
    let onNavigateToPreviousCastingContest: (() -> Void)?
    let sessionContext: VioSessionContext?
    @StateObject private var defaultSessionContext: VioSessionContext

    @StateObject private var playerViewModel = VideoPlayerViewModel()
    @StateObject private var eventStreamer = EventStreamerManager()
    @StateObject private var campaignManager = CampaignManager.shared
    @StateObject private var productFetchViewModel: ProductFetchViewModel
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
    @State private var showProductDetail = false
    
    public init(
        match: Match,
        onDismiss: @escaping () -> Void,
        onNavigateToNextCastingContest: (() -> Void)? = nil,
        onNavigateToPreviousCastingContest: (() -> Void)? = nil,
        sessionContext: VioSessionContext? = nil
    ) {
        self.match = match
        self.onDismiss = onDismiss
        self.onNavigateToNextCastingContest = onNavigateToNextCastingContest
        self.onNavigateToPreviousCastingContest = onNavigateToPreviousCastingContest
        self.sessionContext = sessionContext
        self._defaultSessionContext = StateObject(wrappedValue: VioSessionContext(broadcastContext: match.toBroadcastContext()))

        // Initialize ProductFetchViewModel
        let config = VioConfiguration.shared
        let baseURL = URL(string: config.environment.graphQLURL)!
        let sdk = SdkClient(baseUrl: baseURL, apiKey: config.apiKey)
        _productFetchViewModel = StateObject(wrappedValue: ProductFetchViewModel(
            sdk: sdk,
            currency: "USD", // Will be updated from cartManager
            country: "US" // Will be updated from cartManager
        ))
    }
    
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
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Video Player Layer
                VStack(spacing: 0) {
                    ZStack {
                        if let player = playerViewModel.player {
                            CustomVideoPlayerView(player: player)
                                .aspectRatio(16/9, contentMode: .fit)
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
                                    .progressViewStyle(CircularProgressViewStyle(tint: VioColors.primary))
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
                .contentShape(Rectangle())
                .onTapGesture {
                    playerViewModel.toggleControlsVisibility()
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
                .allowsHitTesting(true)
            }

            ZStack {
                VCastingChatOverlay(
                    showControls: $playerViewModel.showControls,
                    onExpandedChange: { expanded in
                        isChatExpanded = expanded
                    }
                )
            }
            
            // Live Badge
            VStack {
                HStack {
                    Spacer()
                    
                    liveBadge
                        .padding(.top, isLandscape ? 8 : 24)
                        .padding(.trailing, 16)
                }
                
                Spacer()
            }
            
            // Poll Overlay (alineado con TV2: respeta estado del chat y onVote)
            if let poll = eventStreamer.currentPoll, showPoll {
                VEngagementPollOverlay(
                    question: poll.question,
                    subtitle: nil,
                    options: poll.options.map { option in
                        VEngagementPollOverlayOption(
                            id: option.id.uuidString,
                            text: option.text,
                            avatarUrl: option.avatarUrl
                        )
                    },
                    duration: poll.duration,
                    isChatExpanded: isChatExpanded,
                    onVote: { option in
                        VioLogger.debug("Poll vote: \(option)", component: "VCastingVideoPlayer")
                    },
                    onDismiss: {
                        withAnimation {
                            showPoll = false
                        }
                    }
                )
            }
            
            // Product Overlay (sobre el chat y poll)
            if let productEvent = eventStreamer.currentProduct, showProduct {
                VEngagementProductOverlay(
                    product: VEngagementProductData(
                        productId: productEvent.productId,
                        name: productFetchViewModel.product?.title ?? productEvent.name,
                        description: productFetchViewModel.product?.description ?? productEvent.description,
                        price: productFetchViewModel.product != nil 
                            ? formatProductPrice(productFetchViewModel.product!.price)
                            : productEvent.price,
                        imageUrl: productFetchViewModel.product?.images.first?.url ?? productEvent.imageUrl,
                        discountPercentage: calculateDiscountPercentage(productFetchViewModel.product)
                    ),
                    isChatExpanded: isChatExpanded,
                    isLoading: productFetchViewModel.isLoading,
                    onAddToCart: {
                        if let apiProduct = productFetchViewModel.product {
                            let product = convertDtoToProduct(apiProduct)
                            Task {
                                await cartManager.addProduct(product, quantity: 1)
                                VioLogger.debug("Product added to cart: \(apiProduct.title)", component: "VCastingVideoPlayer")
                            }
                        } else {
                            VioLogger.warning("Product API not yet available", component: "VCastingVideoPlayer")
                        }
                    },
                    onShowDetail: {
                        if productFetchViewModel.product != nil {
                            showProductDetail = true
                        }
                    },
                    onDismiss: {
                        withAnimation {
                            showProduct = false
                        }
                    }
                )
                .task(id: productEvent.productId) {
                    productFetchViewModel.currency = cartManager.currency
                    productFetchViewModel.country = cartManager.country
                    await productFetchViewModel.fetchProduct(productId: productEvent.productId)
                }
                .sheet(isPresented: $showProductDetail) {
                    if let apiProduct = productFetchViewModel.product {
                        VProductDetailOverlay(
                            product: convertDtoToProduct(apiProduct),
                            onDismiss: {
                                showProductDetail = false
                            },
                            onAddToCart: { product in
                                showProductDetail = false
                            }
                        )
                        .environmentObject(cartManager)
                    }
                }
            }
            
            // Contest Overlay
            if let contest = eventStreamer.currentContest, showContest {
                VEngagementContestOverlay(
                    name: contest.name,
                    prize: contest.prize,
                    deadline: contest.deadline,
                    maxParticipants: contest.maxParticipants,
                    prizes: nil,
                    isChatExpanded: isChatExpanded,
                    onJoin: {
                        VioLogger.debug("Contest joined: \(contest.name)", component: "VCastingVideoPlayer")
                    },
                    onDismiss: {
                        withAnimation {
                            showContest = false
                        }
                    }
                )
            }
            
            // Floating cart indicator - SIEMPRE visible en el video player
            VFloatingCartIndicator(
                customPadding: EdgeInsets(
                    top: 0,
                    leading: 0,
                    bottom: 100,
                    trailing: 16
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
        .ignoresSafeArea() // Full screen
        .environmentObject(effectiveSessionContext)
        .task {
            await BroadcastContextSetup.setup(
                sessionContext: effectiveSessionContext,
                fallbackBroadcastContext: { match.toBroadcastContext(channelId: VioConfiguration.shared.campaignConfiguration.channelId) }
            )
        }
        .onAppear {
            playerViewModel.setupPlayer()
            // Enable all orientations for video playback
            setOrientation(.allButUpsideDown)
            
            // Conectar event streamer
            eventStreamer.connect()
        }
        .onDisappear {
            playerViewModel.cleanup()
            // Return to portrait when dismissed
            setOrientation(.portrait)
            
            // Desconectar event streamer
            eventStreamer.disconnect()
        }
        .onReceive(eventStreamer.$currentPoll) { newPoll in
            guard let poll = newPoll else { return }
            withAnimation {
                showPoll = true
            }
            if let duration = newPoll?.duration {
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(duration)) {
                    withAnimation {
                        showPoll = false
                    }
                }
            }
        }
        .onReceive(eventStreamer.$currentProduct) { newProduct in
            guard newProduct != nil else { return }
            withAnimation {
                showProduct = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                withAnimation {
                    showProduct = false
                }
            }
        }
        .onReceive(eventStreamer.$currentContest) { newContest in
            guard newContest != nil else { return }
            withAnimation {
                showContest = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
                withAnimation {
                    showContest = false
                }
            }
        }
    }
    
    // MARK: - Top Bar
    private var topBar: some View {
        HStack {
            Button(action: { onDismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.black.opacity(0.3))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            HStack(spacing: 16) {
                Button(action: {}) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                }
                
                Button(action: {}) {
                    Image(systemName: "airplayvideo")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    // MARK: - Bottom Controls
    private var bottomControls: some View {
        VStack(spacing: 16) {
            // Progress Bar
            VStack(spacing: 8) {
                HStack {
                    Text(playerViewModel.currentTimeText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text(playerViewModel.durationText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                }
                
                GeometryReader { progressGeometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.white.opacity(0.3))
                            .frame(height: 4)
                        
                        Rectangle()
                            .fill(VioColors.primary)
                            .frame(width: progressGeometry.size.width * playerViewModel.progress, height: 4)
                    }
                }
                .frame(height: 4)
            }
            .padding(.horizontal, 16)
            
            // Control Buttons
            HStack(spacing: 24) {
                Button(action: { playerViewModel.toggleMute() }) {
                    Image(systemName: playerViewModel.isMuted ? "speaker.slash.fill" : "speaker.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                }
                
                Button(action: {
                    // Demo: Navigate to previous Elkjøp contest, fallback to seek backward
                    if let onPrevious = onNavigateToPreviousCastingContest {
                        onPrevious()
                    } else {
                        playerViewModel.seekBackward()
                    }
                }) {
                    Image(systemName: "gobackward.10")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                }
                
                Button(action: { playerViewModel.togglePlayPause() }) {
                    Image(systemName: playerViewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(.white)
                }
                
                Button(action: {
                    // Demo: Navigate to next Elkjøp contest, fallback to seek forward
                    if let onNext = onNavigateToNextCastingContest {
                        onNext()
                    } else {
                        playerViewModel.seekForward()
                    }
                }) {
                    Image(systemName: "goforward.10")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                }
                
                Button(action: { playerViewModel.togglePlaybackSpeed() }) {
                    Text("\(Int(playerViewModel.playbackSpeed))x")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 100)
    }
    
    // MARK: - Live Badge
    private var liveBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(VioColors.primary)
                .frame(width: 8, height: 8)
                .scaleEffect(1.2)
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: playerViewModel.isPlaying)
            
            Text("LIVE")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.6))
        .cornerRadius(16)
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
    
    /// Formatea el precio de un ProductDto para display
    private func formatProductPrice(_ price: PriceDto) -> String {
        let priceToShow = price.amountInclTaxes ?? price.amount
        return "\(price.currencyCode) \(String(format: "%.2f", priceToShow))"
    }
    
    /// Calcula el porcentaje de descuento de un ProductDto
    private func calculateDiscountPercentage(_ product: ProductDto?) -> Int? {
        guard let product = product else { return nil }
        
        let currentPrice = product.price.amountInclTaxes ?? product.price.amount
        let originalPrice = product.price.compareAtInclTaxes ?? product.price.compareAt
        
        guard let compareAt = originalPrice, compareAt > currentPrice else {
            return nil
        }
        
        let discount = ((compareAt - currentPrice) / compareAt) * 100
        return Int(discount.rounded())
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
    
    // MARK: - Broadcast Context Setup

    private var effectiveSessionContext: VioSessionContext {
        sessionContext ?? defaultSessionContext
    }

}

// MARK: - Custom Video Player View
struct CustomVideoPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspectFill
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        // No updates needed
    }
}

// MARK: - Orientation Helper
func setOrientation(_ orientation: UIInterfaceOrientationMask) {
    if #available(iOS 16.0, *) {
    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
        windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: orientation))
        }
    } else {
        // Fallback for iOS 15.0: Use UIDevice orientation change
        // Note: This is a workaround and may not work in all scenarios
        if let orientationValue = orientationToUIDeviceOrientation(orientation) {
            UIDevice.current.setValue(orientationValue.rawValue, forKey: "orientation")
        }
    }
}

// Helper function to convert UIInterfaceOrientationMask to UIDeviceOrientation
private func orientationToUIDeviceOrientation(_ mask: UIInterfaceOrientationMask) -> UIDeviceOrientation? {
    switch mask {
    case .portrait:
        return .portrait
    case .landscapeLeft:
        return .landscapeLeft
    case .landscapeRight:
        return .landscapeRight
    case .portraitUpsideDown:
        return .portraitUpsideDown
    case .landscape:
        // Default to landscapeLeft for landscape mask
        return .landscapeLeft
    default:
        return nil
    }
}

struct VCastingVideoPlayer_Previews: PreviewProvider {
    static var previews: some View {
        VCastingVideoPlayer(match: Match.barcelonaPSG, onDismiss: {})
            .environmentObject(CartManager())
    }
}