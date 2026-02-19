import SwiftUI

/// Componente de encuesta/poll para TV2
/// Horizontal: se muestra a la derecha del chat
/// Vertical: se muestra sobre el chat, más pequeño
struct TV2PollOverlay: View {
    let poll: PollEventData
    let isChatExpanded: Bool
    let onVote: (String) -> Void
    let onDismiss: () -> Void
    
    @State private var selectedOption: String?
    @State private var hasVoted = false
    @State private var showResults = false
    @State private var dragOffset: CGFloat = 0
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    private var isLandscape: Bool {
        verticalSizeClass == .compact
    }
    
    // Ajustar bottom padding basado en si el chat está expandido
    private var bottomPadding: CGFloat {
        if isLandscape {
            return isChatExpanded ? 250 : 156 // En landscape, espacio para el chat con 2 mensajes (140 + 16)
        } else {
            return isChatExpanded ? 250 : 80 // Más espacio cuando el chat está expandido
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if isLandscape {
                // Horizontal: ocupa lado derecho
                Spacer()
                HStack(spacing: 0) {
                    Spacer()
                    pollCard
                        .frame(width: 300)
                        .padding(.trailing, 16)
                        .padding(.bottom, 16)
                        .offset(x: dragOffset)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    if value.translation.width > 0 {
                                        dragOffset = value.translation.width
                                    }
                                }
                                .onEnded { value in
                                    if value.translation.width > 100 {
                                        onDismiss()
                                    } else {
                                        withAnimation(.spring()) {
                                            dragOffset = 0
                                        }
                                    }
                                }
                        )
                }
            } else {
                // Vertical: sobre el chat, más compacto
                Spacer()
                pollCard
                    .padding(.horizontal, 16)
                    .padding(.bottom, bottomPadding) // Ajuste dinámico según estado del chat
                    .offset(y: dragOffset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if value.translation.height > 0 {
                                    dragOffset = value.translation.height
                                }
                            }
                            .onEnded { value in
                                if value.translation.height > 100 {
                                    onDismiss()
                                } else {
                                    withAnimation(.spring()) {
                                        dragOffset = 0
                                    }
                                }
                            }
                    )
            }
        }
    }
    
    private var pollCard: some View {
        ZStack {
            // Front side - Poll question
            if !showResults {
                pollFrontView
                    .rotation3DEffect(
                        .degrees(0),
                        axis: (x: 0, y: 1, z: 0)
                    )
            }
            
            // Back side - Results
            if showResults {
                pollResultsView
                    .rotation3DEffect(
                        .degrees(180),
                        axis: (x: 0, y: 1, z: 0)
                    )
            }
        }
        .rotation3DEffect(
            .degrees(showResults ? 180 : 0),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.5
        )
    }
    
    private var pollFrontView: some View {
        VStack(spacing: 0) {
            VStack(spacing: isLandscape ? 12 : 10) {
                // Drag indicator
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 32, height: 4)
                    .padding(.top, 8)
                
                // Sponsor badge arriba a la izquierda
                if let campaignLogo = poll.campaignLogo, !campaignLogo.isEmpty {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sponset av")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                            
                            AsyncImage(url: URL(string: campaignLogo)) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxWidth: 80, maxHeight: 24)
                                case .empty:
                                    ProgressView()
                                        .scaleEffect(0.5)
                                        .frame(width: 80, height: 24)
                                case .failure:
                                    EmptyView()
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 4)
                }
                
                // Title (main question)
                Text(poll.question)
                    .font(.system(size: isLandscape ? 16 : 14, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 16)
                
                // Subtitle (optional helper text)
                Text("Få raskere tilgang til kampene fra forsiden")
                    .font(.system(size: isLandscape ? 12 : 10, weight: .regular))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .padding(.horizontal, 16)
                
                // Options
                VStack(spacing: isLandscape ? 8 : 6) {
                    ForEach(Array(poll.options.enumerated()), id: \.offset) { index, option in
                        pollOptionButton(option: option, index: index)
                    }
                }
                
                // Timer
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: isLandscape ? 10 : 9))
                    Text("\(poll.duration)s")
                        .font(.system(size: isLandscape ? 11 : 10))
                }
                .foregroundColor(.white.opacity(0.6))
                .padding(.top, 4)
            }
            .padding(isLandscape ? 16 : 14)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.4))
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)
                    )
            )
            .shadow(color: .black.opacity(0.6), radius: 20, x: 0, y: 8)
        }
    }
    
    private var pollResultsView: some View {
        VStack(spacing: 0) {
            VStack(spacing: isLandscape ? 12 : 10) {
                // Drag indicator
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 32, height: 4)
                    .padding(.top, 8)
                
                // Title
                Text("Resultater")
                    .font(.system(size: isLandscape ? 18 : 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                
                Text("Takk for at du stemte!")
                    .font(.system(size: isLandscape ? 13 : 10, weight: .regular))
                    .foregroundColor(TV2Theme.Colors.primary)
                    .padding(.horizontal, 16)
                
                // Results bars
                VStack(spacing: isLandscape ? 12 : 8) {
                    ForEach(Array(poll.options.enumerated()), id: \.offset) { index, option in
                        resultBar(option: option, isSelected: option.text == selectedOption)
                    }
                }
                .padding(.top, isLandscape ? 12 : 8)
            }
            .padding(isLandscape ? 20 : 14)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.4))
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)
                    )
            )
            .shadow(color: .black.opacity(0.6), radius: 20, x: 0, y: 8)
        }
    }
    
    private func resultBar(option: PollOption, isSelected: Bool) -> some View {
        let percentage = calculatePercentage(for: option)
        
        return VStack(alignment: .leading, spacing: isLandscape ? 6 : 4) {
            HStack {
                Text(option.text)
                    .font(.system(size: isLandscape ? 15 : 12, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(Int(percentage))%")
                    .font(.system(size: isLandscape ? 15 : 12, weight: .bold))
                    .foregroundColor(isSelected ? TV2Theme.Colors.primary : .white)
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: isLandscape ? 10 : 8)
                        .fill(Color.white.opacity(0.2))
                    
                    // Fill
                    RoundedRectangle(cornerRadius: isLandscape ? 10 : 8)
                        .fill(isSelected ? TV2Theme.Colors.primary : Color(hex: "5B5FCF"))
                        .frame(width: geometry.size.width * (percentage / 100))
                }
            }
            .frame(height: isLandscape ? 12 : 6)
        }
        .padding(.horizontal, 16)
    }
    
    private func calculatePercentage(for option: PollOption) -> Double {
        // Simulate results - in production, this would come from the server
        guard let selected = selectedOption else { return 0 }
        
        if option.text == selected {
            return 75.0 // Selected option gets 75%
        } else {
            let remaining = 25.0
            let otherOptions = poll.options.filter { $0.text != selected }.count
            return remaining / Double(otherOptions)
        }
    }
    
    private func pollOptionButton(option: PollOption, index: Int) -> some View {
        Button(action: {
            guard !hasVoted else { return }
            selectedOption = option.text
            hasVoted = true
            onVote(option.text)
            
            // Simular delay para "obtener resultados" y luego hacer flip
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeInOut(duration: 0.6)) {
                    showResults = true
                }
            }
        }) {
            HStack(spacing: 10) {
                // Avatar/Icon circle
                if let avatarUrl = option.avatarUrl, !avatarUrl.isEmpty {
                    // Mostrar imagen/logo si hay avatarUrl
                    AsyncImage(url: URL(string: avatarUrl)) { phase in
                        switch phase {
                        case .success(let image):
                            // Logo/escudo sobre fondo circular blanco
                            Circle()
                                .fill(Color.white)
                                .frame(width: isLandscape ? 40 : 36, height: isLandscape ? 40 : 36)
                                .overlay(
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: isLandscape ? 30 : 26, height: isLandscape ? 30 : 26)
                                )
                                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                        case .empty:
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: isLandscape ? 40 : 36, height: isLandscape ? 40 : 36)
                                .overlay(
                                    ProgressView()
                                        .scaleEffect(0.6)
                                        .tint(.white)
                                )
                        case .failure:
                            // Fallback: primera letra
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "5B5FCF"), Color(hex: "7B7FEF")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: isLandscape ? 40 : 36, height: isLandscape ? 40 : 36)
                                .overlay(
                                    Text(String(option.text.prefix(1)).uppercased())
                                        .font(.system(size: isLandscape ? 16 : 14, weight: .bold))
                                        .foregroundColor(.white)
                                )
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    // Sin avatarUrl: mostrar círculo con primera letra
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "5B5FCF"), Color(hex: "7B7FEF")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: isLandscape ? 40 : 36, height: isLandscape ? 40 : 36)
                        .overlay(
                            Text(String(option.text.prefix(1)).uppercased())
                                .font(.system(size: isLandscape ? 16 : 14, weight: .bold))
                                .foregroundColor(.white)
                        )
                }
                
                Text(option.text)
                    .font(.system(size: isLandscape ? 14 : 12, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: isLandscape ? 20 : 18)
                    .fill(
                        selectedOption == option.text 
                        ? Color(hex: "5B5FCF")
                        : Color(hex: "3A3D5C")
                    )
            )
        }
        .disabled(hasVoted)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        TV2PollOverlay(
            poll: PollEventData(
                id: "poll_test",
                question: "Hvilket lag vinner Champions League?",
                options: [
                    PollOption(text: "Barcelona", avatarUrl: "https://upload.wikimedia.org/wikipedia/en/thumb/4/47/FC_Barcelona_%28crest%29.svg/200px-FC_Barcelona_%28crest%29.svg.png"),
                    PollOption(text: "PSG", avatarUrl: "https://upload.wikimedia.org/wikipedia/en/thumb/a/a7/Paris_Saint-Germain_F.C..svg/200px-Paris_Saint-Germain_F.C..svg.png"),
                    PollOption(text: "Real Madrid", avatarUrl: nil),
                    PollOption(text: "Bayern Munich", avatarUrl: nil)
                ],
                duration: 60,
                imageUrl: nil,
                campaignLogo: "http://event-streamer-angelo100.replit.app/objects/uploads/16475fd2-da1f-4e9f-8eb4-362067b27858"
            ),
            isChatExpanded: false,
            onVote: { option in
                print("Votado: \(option)")
            },
            onDismiss: {
                print("Cerrado")
            }
        )
    }
}

