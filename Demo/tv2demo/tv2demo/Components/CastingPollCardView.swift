import SwiftUI

/// Wrapper del pollCard de TV2PollOverlay con tamaño fijo para casting
/// Copia EXACTA del estilo y funcionalidad de TV2PollOverlay
struct CastingPollCardView: View {
    let poll: PollEventData
    let onVote: (String) -> Void
    let onDismiss: () -> Void
    
    @State private var selectedOption: String?
    @State private var hasVoted = false
    @State private var showResults = false
    @State private var dragOffset: CGFloat = 0
    
    var body: some View {
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
        .frame(maxWidth: UIScreen.main.bounds.width - 40) // Margen de 20px a cada lado
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
    
    // MARK: - Front View
    
    private var pollFrontView: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                // Drag indicator
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 32, height: 4)
                    .padding(.top, 8)
                
                // Sponsor badge
                if let campaignLogo = poll.campaignLogo, !campaignLogo.isEmpty {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sponset av")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                            
                            AsyncImage(url: URL(string: campaignLogo)) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable().aspectRatio(contentMode: .fit).frame(maxWidth: 80, maxHeight: 24)
                                case .empty:
                                    ProgressView().scaleEffect(0.5).frame(width: 80, height: 24)
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
                
                // Question
                Text(poll.question)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 16)
                
                // Subtitle
                Text("Få raskere tilgang til kampene fra forsiden")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .padding(.horizontal, 16)
                
                // Options
                VStack(spacing: 6) {
                    ForEach(Array(poll.options.enumerated()), id: \.offset) { index, option in
                        pollOptionButton(option: option)
                    }
                }
                
                // Timer
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 9))
                    Text("\(poll.duration)s")
                        .font(.system(size: 10))
                }
                .foregroundColor(.white.opacity(0.6))
                .padding(.top, 4)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.4))
                    .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                    )
            )
        }
    }
    
    // MARK: - Results View
    
    private var pollResultsView: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                // Drag indicator
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 32, height: 4)
                    .padding(.top, 8)
                
                // Title
                Text("Resultater")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                
                Text("Takk for at du stemte!")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(TV2Theme.Colors.primary)
                    .padding(.horizontal, 16)
                
                // Results bars
                VStack(spacing: 8) {
                    ForEach(Array(poll.options.enumerated()), id: \.offset) { index, option in
                        resultBar(option: option, isSelected: option.text == selectedOption)
                    }
                }
                .padding(.top, 8)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.4))
                    .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                    )
            )
        }
    }
    
    // MARK: - Poll Option Button
    
    private func pollOptionButton(option: PollOption) -> some View {
        Button(action: {
            guard !hasVoted else { return }
            selectedOption = option.text
            hasVoted = true
            onVote(option.text)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeInOut(duration: 0.6)) {
                    showResults = true
                }
            }
        }) {
            HStack(spacing: 10) {
                // Avatar/Icon
                if let avatarUrl = option.avatarUrl, !avatarUrl.isEmpty {
                    AsyncImage(url: URL(string: avatarUrl)) { phase in
                        switch phase {
                        case .success(let image):
                            Circle()
                                .fill(Color.white)
                                .frame(width: 36, height: 36)
                                .overlay(
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 26, height: 26)
                                )
                                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                        case .empty:
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 36, height: 36)
                                .overlay(ProgressView().scaleEffect(0.6).tint(.white))
                        case .failure:
                            Circle()
                                .fill(LinearGradient(
                                    colors: [Color(hex: "5B5FCF"), Color(hex: "7B7FEF")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Text(String(option.text.prefix(1)).uppercased())
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                )
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color(hex: "5B5FCF"), Color(hex: "7B7FEF")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Text(String(option.text.prefix(1)).uppercased())
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        )
                }
                
                Text(option.text)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.15))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Result Bar
    
    private func resultBar(option: PollOption, isSelected: Bool) -> some View {
        let percentage = calculatePercentage(for: option)
        
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(option.text)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(Int(percentage))%")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(isSelected ? TV2Theme.Colors.primary : .white)
            }
            
            // Progress bar con ancho fijo
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 260, height: 32)
                
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? TV2Theme.Colors.primary : Color.white.opacity(0.5))
                    .frame(width: 260 * (percentage / 100), height: 32)
            }
        }
    }
    
    private func calculatePercentage(for option: PollOption) -> CGFloat {
        guard let selected = selectedOption else { return 0 }
        
        if option.text == selected {
            return 75.0
        } else {
            let remaining = 25.0
            let otherOptions = poll.options.filter { $0.text != selected }.count
            return remaining / CGFloat(otherOptions)
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        CastingPollCardView(
            poll: PollEventData(
                id: "1",
                question: "Hvem vinner kampen?",
                options: [
                    PollOption(text: "Barcelona", avatarUrl: "https://upload.wikimedia.org/wikipedia/en/4/47/FC_Barcelona_%28crest%29.svg"),
                    PollOption(text: "PSG", avatarUrl: nil),
                    PollOption(text: "Empate", avatarUrl: nil)
                ],
                duration: 30,
                imageUrl: nil,
                campaignLogo: nil
            ),
            onVote: { _ in },
            onDismiss: {}
        )
    }
}

