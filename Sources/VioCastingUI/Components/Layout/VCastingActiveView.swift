import SwiftUI
import VioUI
import VioCore
import VioEngagementUI
import VioEngagementSystem
import VioDesignSystem
import Combine

/// Vista que se muestra cuando el casting está activo en Viaplay
/// Permite controlar el video y ver los overlays mientras se castea
public struct VCastingActiveView: View {
    let match: Match
    let sessionContext: VioSessionContext?
    @StateObject private var castingManager = CastingManager.shared
    @StateObject private var defaultSessionContext: VioSessionContext

    /// - Parameters:
    ///   - match: Match model for the live event
    ///   - sessionContext: Optional session context (userId, broadcastContext). If nil, a default is created from match.
    public init(match: Match, sessionContext: VioSessionContext? = nil) {
        self.match = match
        self.sessionContext = sessionContext
        self._defaultSessionContext = StateObject(wrappedValue: VioSessionContext(broadcastContext: match.toBroadcastContext()))
    }
    @StateObject private var eventStreamer = EventStreamerManager()
    @StateObject private var chatManager = ChatManager()
    @StateObject private var campaignManager = CampaignManager.shared
    @EnvironmentObject private var cartManager: CartManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var isPlaying = true
    @State private var isChatExpanded = false
    @State private var chatMessage = ""
    @State private var floatingLikes: [FloatingLike] = []
    @State private var videoTime: Int = 0 // Current video time in seconds
    @State private var videoTimer: Timer?
    
    struct FloatingLike: Identifiable {
        let id = UUID()
        let xOffset: CGFloat
    }
    
    private var sdkClient: SdkClient {
        let config = VioConfiguration.shared
        let baseURL = URL(string: config.environment.graphQLURL)!
        return SdkClient(baseUrl: baseURL, apiKey: config.apiKey)
    }
    
    public var body: some View {
        ZStack {
            // Background
            Image(match.backgroundImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
                .blur(radius: 20)
            
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            // Contenido principal
            VStack(spacing: 20) {
                // Header
                castingHeader
                
                Spacer()
                
                // Match info
                matchInfo
                
                Spacer()
                
                // Controles
                playbackControls
                
                Spacer()
                    .frame(minHeight: 40)
                
                // Eventos interactivos
                if let poll = eventStreamer.currentPoll {
                    VEngagementPollCard(
                        question: poll.question,
                        subtitle: nil,
                        options: poll.options.map { option in
                            VEngagementPollOption(
                                id: option.id.uuidString,
                                text: option.text,
                                avatarUrl: option.avatarUrl
                            )
                        },
                        duration: poll.duration,
                        onVote: { optionId in
                            print("📊 [Poll] Votado: \(optionId)")
                        },
                        onDismiss: {
                            eventStreamer.currentPoll = nil
                        }
                    )
                } else if let productEvent = eventStreamer.currentProduct {
                    VEngagementProductCard(
                        product: VEngagementProductData(
                            productId: productEvent.productId,
                            name: productEvent.name,
                            description: productEvent.description,
                            price: "\(productEvent.currency) \(productEvent.price)",
                            imageUrl: productEvent.imageUrl,
                            discountPercentage: nil
                        ),
                        onAddToCart: {
                            print("🛍️ Producto agregado al carrito")
                        },
                        onDismiss: {
                            eventStreamer.currentProduct = nil
                        },
                        onShowDetail: nil
                    )
                    .environmentObject(cartManager)
                } else if let contest = eventStreamer.currentContest {
                    let brandConfig = VioConfiguration.shared.brandConfiguration
                    
                    VEngagementContestCard(
                        title: contest.name,
                        description: "Konkurranse med premie: \(contest.prize)",
                        prize: contest.prize,
                        contestType: nil,
                        imageAsset: nil,
                        brandName: brandConfig.name,
                        brandIcon: brandConfig.iconAsset,
                        displayTime: contest.deadline,
                        onParticipate: {
                            print("🎁 [Contest] Usuario se unió")
                            eventStreamer.currentContest = nil
                        }
                    )
                }
                
                // Chat
                simpleChatPanel
            }
            
            // Floating likes overlay
            ForEach(floatingLikes) { like in
                FloatingLikeView()
                    .offset(x: like.xOffset, y: 0)
                    .offset(y: -100)
                    .animation(.easeOut(duration: 2.5), value: floatingLikes.count)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            floatingLikes.removeAll { $0.id == like.id }
                        }
                    }
            }
            
            // Floating cart indicator
            VFloatingCartIndicator(
                customPadding: EdgeInsets(
                    top: 0,
                    leading: 0,
                    bottom: 100,
                    trailing: 16
                )
            )
            .zIndex(1000)
        }
        .navigationBarHidden(true)
        .environmentObject(effectiveSessionContext)
        .task {
            // Set broadcast context for auto-discovery and context-aware campaigns
            await setupBroadcastContext()
        }
        .onAppear {
            eventStreamer.connect()
            chatManager.startSimulation()
            
            // Set match start time in VideoSyncManager if available
            setupVideoSync()
            
            // Start video time timer (simulates video playback)
            startVideoTimeTimer()
        }
        .onDisappear {
            eventStreamer.disconnect()
            chatManager.stopSimulation()
            
            // Stop video time timer
            stopVideoTimeTimer()
        }
    }
    
    // MARK: - Components
    
    @ViewBuilder
    private var castingHeader: some View {
        let colors = VioColors.adaptive(for: colorScheme)
        HStack(alignment: .top) {
            // Back button
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(colors.textPrimary)
                    .frame(width: 44, height: 44)
            }
            
            // Casting info centrada
            VStack(spacing: 4) {
                Text(match.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(colors.textPrimary)
                
                Text(match.subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(colors.textSecondary)
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
                .foregroundColor(colors.textOnPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(colors.error.opacity(0.8))
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 50)
    }
    
    @ViewBuilder
    private var matchInfo: some View {
        let colors = VioColors.adaptive(for: colorScheme)
        VStack(spacing: 20) {
            // Mensaje de "Casting to..."
            Text("Casting to \(castingManager.selectedDevice?.name ?? "Living TV")")
                .font(.system(size: 17))
                .foregroundColor(colors.textPrimary)
            
                // Progreso/tiempo
            VStack(spacing: 16) {
                // Barra de progreso
                let colors = VioColors.adaptive(for: colorScheme)
                ZStack(alignment: .leading) {
                    // Background
                    Capsule()
                        .fill(colors.textPrimary.opacity(0.3))
                        .frame(height: 4)
                    
                    // Progress (simulado al 50%)
                    Capsule()
                        .fill(colors.primary)
                        .frame(width: (UIScreen.main.bounds.width * 0.6) * 0.5, height: 4)
                }
                .frame(width: UIScreen.main.bounds.width * 0.6, height: 4)
                
                // Tiempo
                let colors2 = VioColors.adaptive(for: colorScheme)
                HStack {
                    Text("3:24:39")
                        .font(.system(size: 15))
                        .foregroundColor(colors2.textPrimary)
                    
                    Spacer()
                    
                    Text("LIVE")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(colors2.primary)
                }
                .frame(width: UIScreen.main.bounds.width * 0.6)
            }
        }
    }
    
    @ViewBuilder
    private var playbackControls: some View {
        let colors = VioColors.adaptive(for: colorScheme)
        HStack(spacing: 40) {
            // Rewind
            Button(action: {}) {
                Image(systemName: "gobackward.30")
                    .font(.system(size: 32))
                    .foregroundColor(colors.textPrimary)
            }
            
            // Play/Pause
            Button(action: { isPlaying.toggle() }) {
                ZStack {
                    Circle()
                        .fill(colors.primary)
                        .frame(width: 70, height: 70)
                    
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 28))
                        .foregroundColor(colors.textOnPrimary)
                }
            }
            
            // Forward
            Button(action: {}) {
                Image(systemName: "goforward.30")
                    .font(.system(size: 32))
                    .foregroundColor(colors.textPrimary)
            }
        }
    }
    
    // MARK: - Chat Panel
    
    private var simpleChatPanel: some View {
        VStack(spacing: 0) {
            // Drag indicator + Header
            let colors = VioColors.adaptive(for: colorScheme)
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(colors.textPrimary.opacity(0.3))
                    .frame(width: 32, height: 4)
                    .padding(.top, 6)
                
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        isChatExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 8) {
                        // Sponsor badge
                        CampaignSponsorBadge(
                            text: "Sponset av",
                            maxWidth: 70,
                            maxHeight: 24,
                            alignment: .leading
                        )
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(VioColors.adaptive(for: colorScheme).surface.opacity(0.3))
                        )
                        
                        Spacer(minLength: 0)
                        
                        // Live Chat indicator
                        let colors2 = VioColors.adaptive(for: colorScheme)
                        HStack(spacing: 4) {
                            Text("LIVE CHAT")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(colors2.textPrimary)
                            
                            Image(systemName: isChatExpanded ? "chevron.down" : "chevron.up")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(colors2.textSecondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                    }
                    .frame(maxWidth: .infinity)
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
                                    Circle()
                                        .fill(message.usernameColor.opacity(0.3))
                                        .frame(width: 28, height: 28)
                                        .overlay(
                                            Text(String(message.username.prefix(1)))
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(message.usernameColor)
                                        )
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 4) {
                                            Text(message.username)
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(message.usernameColor)
                                            
                                            Text(timeAgo(from: message.timestamp))
                                                .font(.system(size: 10))
                                                .foregroundColor(VioColors.adaptive(for: colorScheme).textTertiary)
                                        }
                                        
                                        Text(message.text)
                                            .font(.system(size: 14))
                                            .foregroundColor(VioColors.adaptive(for: colorScheme).textPrimary)
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
                    .background(VioColors.adaptive(for: colorScheme).border)
                
                // Input bar
                let colors3 = VioColors.adaptive(for: colorScheme)
                HStack(spacing: 10) {
                    TextField("Send a message...", text: $chatMessage)
                        .font(.system(size: 14))
                        .foregroundColor(colors3.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(colors3.surfaceSecondary.opacity(0.5))
                        )
                    
                    Button {
                        sendChatMessage()
                    } label: {
                        let colors = VioColors.adaptive(for: colorScheme)
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(chatMessage.isEmpty ? colors.textSecondary : colors.primary)
                            .padding(8)
                            .background(
                                Circle()
                                    .fill(chatMessage.isEmpty ? colors.surfaceSecondary : colors.primary.opacity(0.2))
                            )
                    }
                    .disabled(chatMessage.isEmpty)
                    
                    Button(action: {
                        sendFloatingLike()
                    }) {
                        let colors = VioColors.adaptive(for: colorScheme)
                        Image(systemName: "hand.thumbsup.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(colors.primary)
                            .padding(8)
                            .background(
                                Circle()
                                    .fill(colors.primary.opacity(0.2))
                            )
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(VioColors.adaptive(for: colorScheme).background)
            }
        }
        .frame(width: isChatExpanded ? 400 : UIScreen.main.bounds.width, height: isChatExpanded ? 280 : 60)
        .background(
            RoundedRectangle(cornerRadius: isChatExpanded ? VioBorderRadius.large : 0)
                .fill(VioColors.adaptive(for: colorScheme).surface.opacity(0.4))
                .background(
                    RoundedRectangle(cornerRadius: isChatExpanded ? VioBorderRadius.large : 0)
                        .fill(.ultraThinMaterial)
                )
        )
        .animation(.spring(response: 0.3), value: isChatExpanded)
    }
    
    private func sendChatMessage() {
        guard !chatMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let colors = VioColors.adaptive(for: colorScheme)
        let message = ChatMessage(
            username: "Angelo",
            text: chatMessage,
            usernameColor: colors.primary,
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
    
    // MARK: - Broadcast Context Setup

    private var effectiveSessionContext: VioSessionContext {
        sessionContext ?? defaultSessionContext
    }

    /// Sets up broadcast context for auto-discovery and context-aware campaigns.
    /// Uses broadcastContext from VioSessionContext when provided (e.g. broadcastId from backend).
    /// When contentId + country are set, validates via GET /v1/sdk/broadcast before showing engagement.
    private func setupBroadcastContext() async {
        let config = VioConfiguration.shared
        let autoDiscover = config.campaignConfiguration.autoDiscover

        // ContentId flow: validate before discoverCampaigns/loadEngagement
        if let contentId = effectiveSessionContext.contentId, let country = effectiveSessionContext.country {
            let result = await BroadcastValidationService.validate(contentId: contentId, country: country)
            print("🎯 [VCastingActiveView] contentId validation: hasEngagement=\(result.hasEngagement)")

            if !result.hasEngagement {
                print("🎯 [VCastingActiveView] No engagement for contentId=\(contentId), skipping discoverCampaigns and loadEngagement")
                return
            }

            guard let broadcastId = result.broadcastId else {
                print("🎯 [VCastingActiveView] hasEngagement=true but no broadcastId in response")
                return
            }

            let broadcastContext = BroadcastContext(
                broadcastId: broadcastId,
                broadcastName: result.broadcastName,
                startTime: nil,
                channelId: nil,
                metadata: nil
            )
            effectiveSessionContext.configure(broadcastContext: broadcastContext, useBackendEngagement: true)

            print("🎯 [VCastingActiveView] contentId flow: using broadcastId=\(broadcastId)")
            if autoDiscover {
                await campaignManager.discoverCampaigns(broadcastId: broadcastId)
            }
            await campaignManager.setBroadcastContext(broadcastContext)
            await EngagementManager.shared.loadEngagement(for: broadcastContext, useBackend: true)
            return
        }

        // Legacy flow: broadcastContext from session or match
        let broadcastContext: BroadcastContext
        if let ctx = effectiveSessionContext.broadcastContext {
            broadcastContext = ctx
        } else {
            broadcastContext = match.toBroadcastContext(channelId: config.campaignConfiguration.channelId)
            effectiveSessionContext.configure(broadcastContext: broadcastContext)
        }

        print("🎯 [VCastingActiveView] Setting up broadcast context: \(broadcastContext.broadcastId)")

        if autoDiscover {
            print("🎯 [VCastingActiveView] Auto-discovery enabled, discovering campaigns for broadcast: \(broadcastContext.broadcastId)")
            await campaignManager.discoverCampaigns(broadcastId: broadcastContext.broadcastId)
            await campaignManager.setBroadcastContext(broadcastContext)
        } else {
            print("🎯 [VCastingActiveView] Legacy mode, setting broadcast context")
            await campaignManager.setBroadcastContext(broadcastContext)
        }

        await EngagementManager.shared.loadEngagement(for: broadcastContext)
    }
    
    // MARK: - Video Sync Setup
    
    /// Sets up video synchronization with VideoSyncManager
    private func setupVideoSync() {
        let broadcastContext = effectiveSessionContext.broadcastContext ?? match.toBroadcastContext()
        
        // Set broadcast start time if available in BroadcastContext
        // For demo purposes, we'll use a default broadcast start time
        // In production, this should come from the Match model or backend
        if let startTimeString = broadcastContext.startTime {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let broadcastStartTime = formatter.date(from: startTimeString) {
                VideoSyncManager.shared.setBroadcastStartTime(broadcastStartTime, for: broadcastContext.broadcastId)
            } else {
                // Try without fractional seconds
                let simpleFormatter = ISO8601DateFormatter()
                if let broadcastStartTime = simpleFormatter.date(from: startTimeString) {
                    VideoSyncManager.shared.setBroadcastStartTime(broadcastStartTime, for: broadcastContext.broadcastId)
                }
            }
        } else {
            // For demo: use current time as broadcast start time
            // In production, this should come from the backend
            let defaultBroadcastStartTime = Date()
            VideoSyncManager.shared.setBroadcastStartTime(defaultBroadcastStartTime, for: broadcastContext.broadcastId)
        }
    }
    
    /// Starts a timer to update video time periodically
    /// In a real implementation, this would get the time from the video player
    private func startVideoTimeTimer() {
        // Reset video time
        videoTime = 0
        VideoSyncManager.shared.updateVideoTime(0)
        
        // Create timer that updates every second
        // Note: VCastingActiveView is a struct, so we can't use [weak self]
        // We'll use a local counter and update VideoSyncManager
        var timeCounter = 0
        videoTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            timeCounter += 1
            
            // Update VideoSyncManager with current video time
            Task { @MainActor in
                VideoSyncManager.shared.updateVideoTime(timeCounter)
            }
        }
    }
    
    /// Stops the video time timer
    private func stopVideoTimeTimer() {
        videoTimer?.invalidate()
        videoTimer = nil
    }
}

#Preview {
    VCastingActiveView(match: Match.barcelonaPSG)
        .environmentObject(CartManager())
}

