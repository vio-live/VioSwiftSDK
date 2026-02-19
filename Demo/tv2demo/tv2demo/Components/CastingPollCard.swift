import SwiftUI

/// Versión compacta de poll específica para la vista de casting
struct CastingPollCard: View {
    let poll: PollEventData
    let onVote: (String) -> Void
    let onDismiss: () -> Void
    
    @State private var hasVoted = false
    @State private var selectedOption: String?
    @State private var showResults = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(poll.question)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    Text("\(poll.duration)s")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                // Close button
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(14)
                }
            }
            
            // Options
            if showResults {
                // Resultados
                VStack(spacing: 8) {
                    ForEach(poll.options, id: \.text) { option in
                        resultBar(for: option)
                    }
                }
            } else {
                // Opciones para votar
                VStack(spacing: 8) {
                    ForEach(poll.options, id: \.text) { option in
                        pollOptionButton(option)
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 420) // ANCHO FIJO
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.6))
                .background(.ultraThinMaterial)
        )
        .cornerRadius(12)
    }
    
    // MARK: - Poll Option Button
    
    private func pollOptionButton(_ option: PollOption) -> some View {
        Button {
            selectedOption = option.text
            hasVoted = true
            onVote(option.text)
            
            withAnimation(.easeInOut(duration: 0.6).delay(0.3)) {
                showResults = true
            }
        } label: {
            HStack(spacing: 12) {
                // Avatar/Logo
                if let avatarUrl = option.avatarUrl, !avatarUrl.isEmpty {
                    AsyncImage(url: URL(string: avatarUrl)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 36, height: 36)
                        case .empty:
                            ProgressView()
                                .tint(.white)
                                .frame(width: 36, height: 36)
                        case .failure:
                            defaultAvatar(for: option)
                        @unknown default:
                            defaultAvatar(for: option)
                        }
                    }
                    .frame(width: 40, height: 40)
                    .background(Color.white)
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                } else {
                    defaultAvatar(for: option)
                }
                
                // Option text
                Text(option.text)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.15))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func defaultAvatar(for option: PollOption) -> some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 40, height: 40)
            
            Text(String(option.text.prefix(1)).uppercased())
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(TV2Theme.Colors.primary)
        }
        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Result Bar
    
    private func resultBar(for option: PollOption) -> some View {
        let percentage = calculatePercentage(for: option)
        let isSelected = option.text == selectedOption
        
        return HStack(spacing: 10) {
            // Avatar/Logo
            if let avatarUrl = option.avatarUrl, !avatarUrl.isEmpty {
                AsyncImage(url: URL(string: avatarUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 30, height: 30)
                    case .empty:
                        ProgressView()
                            .tint(.white)
                            .frame(width: 30, height: 30)
                    case .failure:
                        defaultAvatarSmall(for: option)
                    @unknown default:
                        defaultAvatarSmall(for: option)
                    }
                }
                .frame(width: 32, height: 32)
                .background(Color.white)
                .cornerRadius(16)
            } else {
                defaultAvatarSmall(for: option)
            }
            
            // Option name
            Text(option.text)
                .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                .foregroundColor(.white)
                .frame(width: 80, alignment: .leading)
            
            // Progress bar
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.15))
                    .frame(maxWidth: 200, maxHeight: 32)
                
                GeometryReader { geometry in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? TV2Theme.Colors.primary : Color.white.opacity(0.3))
                        .frame(width: max(40, geometry.size.width * (percentage / 100)), height: 32)
                }
            }
            .frame(maxWidth: 200, maxHeight: 32)
            
            // Percentage
            Text("\(Int(percentage))%")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 40, alignment: .trailing)
        }
    }
    
    private func defaultAvatarSmall(for option: PollOption) -> some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 32, height: 32)
            
            Text(String(option.text.prefix(1)).uppercased())
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(TV2Theme.Colors.primary)
        }
    }
    
    private func calculatePercentage(for option: PollOption) -> CGFloat {
        guard let selected = selectedOption else { return 0 }
        
        if option.text == selected {
            return 75
        } else {
            let remaining: CGFloat = 25
            let otherOptionsCount = CGFloat(poll.options.count - 1)
            return remaining / otherOptionsCount
        }
    }
}

#Preview {
    ZStack {
        Color.black
        
        CastingPollCard(
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
        .padding()
    }
}

