import SwiftUI

/// Componente de concurso con ruleta animada
/// Usuario se une con "Bli med", cuando termina el contador muestra ruleta giratoria
struct TV2ContestOverlay: View {
    let contest: ContestEventData
    let isChatExpanded: Bool
    let onJoin: () -> Void
    let onDismiss: () -> Void
    
    @State private var hasJoined = false
    @State private var showWheel = false
    @State private var wheelRotation: Double = 0
    @State private var finalPrize: String = ""
    @State private var isSpinning = false
    @State private var countdown: Int = 10 // Countdown en segundos
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
    
    // Premios de la ruleta
    private let prizes = [
        "🎁 Premio Principal",
        "💰 50% Descuento",
        "🎉 Premio Sorpresa",
        "⭐ Vale Regalo",
        "🏆 Premio Especial",
        "🎊 Descuento 30%"
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            if isLandscape {
                // Horizontal: lado derecho
                Spacer()
                HStack(spacing: 0) {
                    Spacer()
                    contestCard
                        .frame(width: 320)
                        .padding(.trailing, 16)
                        .padding(.bottom, 16)
                        .offset(x: dragOffset)
                        .gesture(dragGesture)
                }
            } else {
                // Vertical: sobre el chat
                Spacer()
                contestCard
                    .padding(.horizontal, 16)
                    .padding(.bottom, bottomPadding)
                    .offset(y: dragOffset)
                    .gesture(dragGesture)
            }
        }
        .onAppear {
            startCountdown()
        }
    }
    
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if isLandscape {
                    if value.translation.width > 0 {
                        dragOffset = value.translation.width
                    }
                } else {
                    if value.translation.height > 0 {
                        dragOffset = value.translation.height
                    }
                }
            }
            .onEnded { value in
                let threshold: CGFloat = 100
                if isLandscape {
                    if value.translation.width > threshold {
                        onDismiss()
                    } else {
                        withAnimation(.spring()) {
                            dragOffset = 0
                        }
                    }
                } else {
                    if value.translation.height > threshold {
                        onDismiss()
                    } else {
                        withAnimation(.spring()) {
                            dragOffset = 0
                        }
                    }
                }
            }
    }
    
    private var contestCard: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                if showWheel {
                    wheelView
                } else {
                    contestInfoView
                }
            }
            .padding(16)
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
    
    // MARK: - Contest Info View
    
    private var contestInfoView: some View {
        VStack(spacing: 12) {
            // Drag indicator
            Capsule()
                .fill(Color.white.opacity(0.3))
                .frame(width: 32, height: 4)
            
            // Sponsor badge arriba a la izquierda
            if let campaignLogo = contest.campaignLogo, !campaignLogo.isEmpty {
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
            
            // Contest name
            Text(contest.name)
                .font(.system(size: isLandscape ? 16 : 18, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            
            // Prize
            VStack(spacing: 6) {
                Text("PREMIER")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                
                Text(contest.prize)
                    .font(.system(size: isLandscape ? 13 : 14, weight: .semibold))
                    .foregroundColor(TV2Theme.Colors.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
            )
            
            // Info
            VStack(spacing: 8) {
                HStack {
                    Text("Frist: \(contest.deadline)")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                }
                
                HStack {
                    Text("Maks deltakere: \(contest.maxParticipants)")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                }
            }
            
            // Countdown or button
            if hasJoined {
                VStack(spacing: 8) {
                    Text("Du er med!")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.green)
                    
                    if countdown > 0 {
                        HStack(spacing: 8) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: TV2Theme.Colors.primary))
                                .scaleEffect(0.8)
                            
                            Text("Trekking om \(countdown)s...")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
                .padding(.vertical, 12)
            } else {
                Button(action: {
                    hasJoined = true
                    onJoin()
                }) {
                    Text("Bli med!")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(hex: "2C0D65"))
                        )
                }
            }
        }
    }
    
    // MARK: - Wheel View
    
    private var wheelView: some View {
        VStack(spacing: 20) {
            // Header
            Text(isSpinning ? "Snurrer..." : "Gratulerer!")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            // Wheel
            ZStack {
                // Pointer at top
                Triangle()
                    .fill(TV2Theme.Colors.primary)
                    .frame(width: 24, height: 30)
                    .offset(y: -125)
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    .zIndex(10)
                
                // Wheel circle
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 260, height: 260)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                
                // Wheel segments
                ZStack {
                    ForEach(0..<prizes.count, id: \.self) { index in
                        wheelSegment(index: index)
                    }
                }
                .rotationEffect(.degrees(wheelRotation))
                .frame(width: 250, height: 250)
                
                // Center circle
                Circle()
                    .fill(Color(hex: "120019"))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [TV2Theme.Colors.primary, TV2Theme.Colors.secondary],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 3
                            )
                    )
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .frame(width: 280, height: 280)
            
            // Prize result (oculto, ya se muestra en la ruleta)
        }
    }
    
    private func wheelSegment(index: Int) -> some View {
        let angle = 360.0 / Double(prizes.count)
        let startAngle = angle * Double(index) - 90 // Start from top
        
        return WheelSegmentShape(startAngle: startAngle, angle: angle)
            .fill(segmentColor(index: index))
            .overlay(
                WheelSegmentShape(startAngle: startAngle, angle: angle)
                    .stroke(Color.black.opacity(0.3), lineWidth: 1)
            )
            .overlay(
                // Premio text
                Text(prizes[index])
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                    .rotationEffect(.degrees(startAngle + angle / 2 + 90))
                    .offset(y: -95)
                    .rotationEffect(.degrees(-(startAngle + angle / 2 + 90)))
            )
            .rotationEffect(.degrees(startAngle + angle / 2 + 90))
    }
    
    // Custom wheel segment shape
    struct WheelSegmentShape: Shape {
        let startAngle: Double
        let angle: Double
        
        func path(in rect: CGRect) -> Path {
            var path = Path()
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let radius = min(rect.width, rect.height) / 2
            
            path.move(to: center)
            path.addArc(
                center: center,
                radius: radius,
                startAngle: .degrees(startAngle),
                endAngle: .degrees(startAngle + angle),
                clockwise: false
            )
            path.closeSubpath()
            
            return path
        }
    }
    
    private func segmentColor(index: Int) -> Color {
        let colors: [Color] = [
            Color(hex: "7B5FFF"), // TV2 Primary Purple
            Color(hex: "E893CF"), // TV2 Secondary Pink
            Color(hex: "5E5CE6"), // Deep Blue
            Color(hex: "00D9FF"), // TV2 Accent Cyan
            Color(hex: "9D4EDD"), // Light Purple
            Color(hex: "FF6B9D")  // Bright Pink
        ]
        return colors[index % colors.count]
    }
    
    // MARK: - Helpers
    
    private func startCountdown() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if countdown > 0 {
                countdown -= 1
            } else {
                timer.invalidate()
                if hasJoined {
                    startWheel()
                }
            }
        }
    }
    
    private func startWheel() {
        withAnimation {
            showWheel = true
        }
        
        // Wait a bit then spin
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            spinWheel()
        }
    }
    
    private func spinWheel() {
        isSpinning = true
        
        // Random final position (3-5 full rotations + random angle)
        let rotations = Double.random(in: 3...5)
        let finalAngle = Double.random(in: 0...360)
        let totalRotation = (rotations * 360) + finalAngle
        
        withAnimation(.timingCurve(0.17, 0.67, 0.3, 1.0, duration: 4.0)) {
            wheelRotation = totalRotation
        }
        
        // Show result after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            isSpinning = false
            
            // Calculate which prize based on final angle
            let normalizedAngle = finalAngle.truncatingRemainder(dividingBy: 360)
            let segmentAngle = 360.0 / Double(prizes.count)
            let prizeIndex = Int((360 - normalizedAngle) / segmentAngle) % prizes.count
            finalPrize = prizes[prizeIndex]
        }
    }
}

// MARK: - Triangle Shape

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        TV2ContestOverlay(
            contest: ContestEventData(
                id: "contest_123",
                name: "Gran Sorteo Tech 2024",
                prize: "Gana un MacBook Pro M3, AirPods Pro y más",
                deadline: "2024-12-31",
                maxParticipants: 1000,
                campaignLogo: "https://upload.wikimedia.org/wikipedia/commons/thumb/2/24/Adidas_logo.png/800px-Adidas_logo.png"
            ),
            isChatExpanded: false,
            onJoin: {
                print("Usuario se unió")
            },
            onDismiss: {
                print("Cerrado")
            }
        )
    }
}

