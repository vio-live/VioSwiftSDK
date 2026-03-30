import SwiftUI
import VioUI
import VioCore

/// Vista que se muestra cuando el casting está activo
/// Permite controlar el video y ver los overlays mientras se castea
struct CastingActiveView: View {
    let match: Match
    @StateObject private var castingManager = CastingManager.shared
    // Legacy WebSocketManager removed — was opening 2nd WS to same endpoint as SDK
    @State private var currentPoll: PollEventData? = nil
    @State private var currentProduct: ProductEventData? = nil
    @State private var currentContest: ContestEventData? = nil
    @StateObject private var chatManager = ChatManager()
    @EnvironmentObject private var cartManager: CartManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var isPlaying = true
    @State private var isChatExpanded = false
    @State private var chatMessage = ""
    @State private var floatingLikes: [FloatingLike] = []
    
    struct FloatingLike: Identifiable {
        let id = UUID()
        let xOffset: CGFloat
    }
    
    private var sdkClient: SdkClient {
        let config = VioConfiguration.shared
        let baseURL = URL(string: config.environment.graphQLURL)!
        return SdkClient(baseUrl: baseURL, apiKey: config.apiKey)
    }
    
    var body: some View {
        ZStack {
            // Background
            Image("football_field_bg")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
                .blur(radius: 20)
            
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            // Contenido principal en VStack simple
            VStack(spacing: 20) {
                // Header
                castingHeader
                
                Spacer()
                
                // Match info
                matchInfo
                
                Spacer()
                
                // Controles (ARRIBA de los eventos)
                playbackControls
                
                Spacer()
                    .frame(minHeight: 40) // Espacio entre controles y eventos
            
                // Eventos interactivos (DEBAJO de los controles)
            if let poll = currentPoll {
                    CastingPollCardView(
                    poll: poll,
                    onVote: { option in
                            print("📊 [Poll] Votado: \(option)")
                    },
                    onDismiss: {
                        currentPoll = nil
                    }
                )
                } else if let productEvent = currentProduct {
                    // Componente que carga datos desde Vio API
                    CastingProductCardView(
                        productEvent: productEvent,
                        sdk: sdkClient,
                    currency: cartManager.currency,
                    country: cartManager.country,
                    onAddToCart: { productDto in
                            if let apiProduct = productDto {
                                print("🛍️ Producto de API: \(apiProduct.title)")
                            }
                    },
                    onDismiss: {
                        currentProduct = nil
                    }
                )
                } else if let contest = currentContest {
                    CastingContestCardView(
                    contest: contest,
                    onJoin: {
                            print("🎁 [Contest] Usuario se unió")
                    },
                    onDismiss: {
                        currentContest = nil
                    }
                )
            }
                
                // Chat (sin Spacer arriba para que quede pegado)
                simpleChatPanel
            }
            
            // Floating likes overlay
            ForEach(floatingLikes) { like in
                FloatingLikeView()
                    .offset(x: like.xOffset, y: 0)
                    .offset(y: -100) // Start from chat area
                    .animation(.easeOut(duration: 2.5), value: floatingLikes.count)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            floatingLikes.removeAll { $0.id == like.id }
                        }
                    }
            }
            
            // Floating cart indicator - always visible
            VFloatingCartIndicator(
                customPadding: EdgeInsets(
                    top: 0,
                    leading: 0,
                    bottom: 100,
                    trailing: TV2Theme.Spacing.md
                )
            )
            .zIndex(1000)
        }
        .navigationBarHidden(true)
        .onAppear {
            // Legacy webSocketManager.connect() removed — SDK handles WS via CampaignManager
            chatManager.startSimulation()
        }
        .onDisappear {
            // Legacy webSocketManager.disconnect() removed
            chatManager.stopSimulation()
        }
    }
    
    // MARK: - Chat Panel
    
    private var simpleChatPanel: some View {
        VStack(spacing: 0) {
            // Drag indicator + Header
            VStack(spacing: 4) {
                // Drag indicator
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 32, height: 4)
                    .padding(.top, 6)
                
                // Header
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        isChatExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 8) {
                        // Sponsor badge (top left)
                        HStack(spacing: 4) {
                            Text("Sponset av")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                            
                            AsyncImage(url: URL(string: "http://event-streamer-angelo100.replit.app/objects/uploads/16475fd2-da1f-4e9f-8eb4-362067b27858")) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxWidth: 70, maxHeight: 24)
                                case .empty:
                                    ProgressView()
                                        .scaleEffect(0.5)
                                        .frame(width: 70, height: 24)
                                case .failure:
                                    EmptyView()
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.black.opacity(0.3))
                        )
                        
                        Spacer(minLength: 0)
                        
                        // Live Chat indicator
                        HStack(spacing: 4) {
                            Text("LIVE CHAT")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                            
                            Image(systemName: isChatExpanded ? "chevron.down" : "chevron.up")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                    }
                    .frame(maxWidth: .infinity) // Full width cuando está cerrado o abierto
                    .padding(.horizontal, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.bottom, 8)
            }
            
            // Mensajes (cuando está expandido)
            if isChatExpanded {
                Divider()
                    .background(Color.white.opacity(0.2))
                
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(chatManager.messages.suffix(20)) { message in
                                HStack(alignment: .top, spacing: 8) {
                                    // Avatar (estilo EXACTO de TV2ChatOverlay)
                                    Circle()
                                        .fill(message.usernameColor.opacity(0.3))
                                        .frame(width: 28, height: 28)
                                        .overlay(
                                            Text(String(message.username.prefix(1)))
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(message.usernameColor)
                                        )
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        // Username and time
                                        HStack(spacing: 4) {
                                            Text(message.username)
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(message.usernameColor)
                                            
                                            Text(timeAgo(from: message.timestamp))
                                                .font(.system(size: 10))
                                                .foregroundColor(.white.opacity(0.4))
                                        }
                                        
                                        // Message
                                        Text(message.text)
                                            .font(.system(size: 14))
                                            .foregroundColor(.white.opacity(0.95))
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    
                                    Spacer(minLength: 0)
                                }
                                .padding(.vertical, 4)
                                .frame(width: 350)
                                .id(message.id)
                            }
                        }
                        .padding(14)
                    }
                    .frame(width: 380, height: 150)
                    .onChange(of: chatManager.messages.count) { _ in
                        if let last = chatManager.messages.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                Divider()
                    .background(Color.white.opacity(0.2))
                
                // Input bar
                HStack(spacing: 10) {
                    TextField("Send a message...", text: $chatMessage)
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white.opacity(0.15))
                        )
                    
                    // Send button
                    Button {
                        sendChatMessage()
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(chatMessage.isEmpty ? .white.opacity(0.3) : TV2Theme.Colors.primary)
                            .padding(8)
                            .background(
                                Circle()
                                    .fill(chatMessage.isEmpty ? Color.white.opacity(0.1) : TV2Theme.Colors.primary.opacity(0.2))
                            )
                    }
                    .disabled(chatMessage.isEmpty)
                    
                    // Like button
                    Button(action: {
                        sendFloatingLike()
                    }) {
                        Image(systemName: "hand.thumbsup.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(TV2Theme.Colors.primary)
                            .padding(8)
                            .background(
                                Circle()
                                    .fill(TV2Theme.Colors.primary.opacity(0.2))
                            )
                    }
                }
                .frame(maxWidth: .infinity) // Todo el ancho disponible
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(hex: "120019"))
            }
        }
        .frame(width: isChatExpanded ? 400 : UIScreen.main.bounds.width, height: isChatExpanded ? 280 : 60) // Cerrado: full width x 60px, Abierto: 400px x 280px
        .background(
            RoundedRectangle(cornerRadius: isChatExpanded ? 20 : 0) // Sin bordes redondeados cuando está cerrado (full width)
                .fill(Color.black.opacity(0.4))
                .background(
                    RoundedRectangle(cornerRadius: isChatExpanded ? 20 : 0)
                        .fill(.ultraThinMaterial)
                )
        )
        .animation(.spring(response: 0.3), value: isChatExpanded)
    }
    
    private func sendChatMessage() {
        guard !chatMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let message = ChatMessage(
            username: "Angelo",
            text: chatMessage,
            usernameColor: TV2Theme.Colors.secondary,
            likes: 0,
            timestamp: Date()
        )
        
        chatManager.addMessage(message)
        chatMessage = ""
    }
    
    private func timeAgo(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        return "\(hours)h"
    }
    
    private func sendFloatingLike() {
        let randomOffset = CGFloat.random(in: -80...80)
        let like = FloatingLike(xOffset: randomOffset)
        
        withAnimation {
            floatingLikes.append(like)
        }
    }
    
    // MARK: - Conversion Helpers (from TV2VideoPlayer)
    
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
    
    // MARK: - Components
    
    private var castingHeader: some View {
        HStack(alignment: .top) {
            // Back button
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
            }
            
            // Casting info centrada
            VStack(spacing: 4) {
                Text(match.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(match.subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.top, 8)
            
            // Stop Casting button
            Button(action: {
                castingManager.stopCasting()
                dismiss()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "tv.slash")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Stop")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.red.opacity(0.8))
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 50)
    }
    
    private var matchInfo: some View {
        VStack(spacing: 20) {
            // Mensaje de "Casting to..."
            Text("Casting to \(castingManager.selectedDevice?.name ?? "Living TV")")
                .font(.system(size: 17))
                .foregroundColor(.white)
            
            // Progreso/tiempo
            VStack(spacing: 16) {
                // Barra de progreso
                    ZStack(alignment: .leading) {
                        // Background
                        Capsule()
                            .fill(Color.white.opacity(0.3))
                            .frame(height: 4)
                        
                        // Progress (simulado al 50%)
                        Capsule()
                            .fill(Color.white)
                        .frame(width: (UIScreen.main.bounds.width * 0.6) * 0.5, height: 4) // 60% del ancho de pantalla, 50% de progreso
                }
                .frame(width: UIScreen.main.bounds.width * 0.6, height: 4) // Limitar a 60% del ancho de pantalla
                
                // Tiempo
                HStack {
                    Text("3:24:39")
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("LIVE")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(width: UIScreen.main.bounds.width * 0.6) // Mismo ancho que la barra
            }
        }
    }
    
    private var playbackControls: some View {
        HStack(spacing: 40) {
            // Rewind
            Button(action: {}) {
                Image(systemName: "gobackward.30")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
            }
            
            // Play/Pause
            Button(action: { isPlaying.toggle() }) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 70, height: 70)
                    
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.black)
                }
            }
            
            // Forward
            Button(action: {}) {
                Image(systemName: "goforward.30")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
            }
        }
    }
}

#Preview {
    CastingActiveView(match: Match.barcelonaPSG)
        .environmentObject(CartManager())
}

