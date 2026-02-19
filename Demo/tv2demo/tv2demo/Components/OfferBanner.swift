import SwiftUI

/// Offer Banner View (for NavigationLink)
/// Version without internal button for use with NavigationLink
struct OfferBannerView: View {
    let title: String
    let subtitle: String?
    
    @State private var timeRemaining: TimeInterval = 2 * 24 * 3600 + 2 * 3600 // 2 días, 2 horas
    @State private var timer: Timer?
    
    init(
        title: String = "Ukens tilbud",
        subtitle: String? = "Se denne ukes beste tilbud"
    ) {
        self.title = title
        self.subtitle = subtitle
    }
    
    var body: some View {
        ZStack {
            // Background layer
            backgroundLayer
            
            // Content in two columns
            HStack(alignment: .center, spacing: 16) {
                // Left column: Logo, title, subtitle, countdown
                VStack(alignment: .leading, spacing: 4) {
                    // Logo
                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 16)
                    
                    // Title
                    Text(title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    // Subtitle
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    // Countdown analógico
                    analogCountdown
                }
                
                Spacer()
                
                // Right column: Discount badge + Button (centered vertically)
                VStack(spacing: 8) {
                    // Discount badge
                    Text("Opp til 30%")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(TV2Theme.Colors.background)
                        )
                    
                    // Button
                    HStack(spacing: 6) {
                        Text("Se alle tilbud")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(TV2Theme.Colors.primary)
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(height: 160)
        .cornerRadius(TV2Theme.CornerRadius.medium)
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        .onAppear {
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    // MARK: - Background
    
    private var backgroundLayer: some View {
        ZStack(alignment: .leading) {
            // Background with image and overlays
            ZStack {
                // Background image (football field)
                Image("football_field_bg")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                
                // Dark overlay para legibilidad
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.4),
                        Color.black.opacity(0.2)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
            .clipped()
        }
    }
    
    
    // MARK: - Analog Countdown
    
    private var analogCountdown: some View {
        let days = Int(timeRemaining) / 86400
        let hours = (Int(timeRemaining) % 86400) / 3600
        let minutes = (Int(timeRemaining) % 3600) / 60
        let seconds = Int(timeRemaining) % 60
        
        return HStack(spacing: 4) {
            // Días
            if days > 0 {
                CountdownUnit(value: days, label: days == 1 ? "dag" : "dager")
            }
            
            // Horas
            if days > 0 || hours > 0 {
                CountdownUnit(value: hours, label: hours == 1 ? "time" : "timer")
            }
            
            // Minutos
            CountdownUnit(value: minutes, label: "min")
            
            // Segundos
            CountdownUnit(value: seconds, label: "sek")
        }
        .padding(.vertical, 3)
    }
    
    // MARK: - Countdown Logic
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                timer?.invalidate()
            }
        }
    }
}

/// Countdown Unit Component (estilo analógico)
struct CountdownUnit: View {
    let value: Int
    let label: String
    
    var body: some View {
        VStack(spacing: 1) {
            // Dígitos
            Text(String(format: "%02d", value))
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .frame(minWidth: 24)
                .padding(.vertical, 2)
                .padding(.horizontal, 5)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                )
            
            // Label
            Text(label)
                .font(.system(size: 7, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
        }
    }
}

/// Offer Banner Component (with button)
/// Banner promocional con imagen de fondo para ofertas especiales
struct OfferBanner: View {
    let title: String
    let subtitle: String?
    let onTap: () -> Void
    
    @State private var timeRemaining: TimeInterval = 2 * 24 * 3600 + 2 * 3600 // 2 días, 2 horas
    @State private var timer: Timer?
    
    init(
        title: String = "Ukens tilbud",
        subtitle: String? = "Se denne ukes beste tilbud",
        onTap: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.onTap = onTap
    }
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background layer
                backgroundLayer
                
                // Content in two columns
                HStack(alignment: .center, spacing: 16) {
                    // Left column: Logo, title, subtitle, countdown
                    VStack(alignment: .leading, spacing: 4) {
                        // Logo
                        Image("logo")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 16)
                        
                        // Title
                        Text(title)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        
                        // Subtitle
                        if let subtitle = subtitle {
                            Text(subtitle)
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        
                        // Countdown analógico
                        analogCountdown
                    }
                    
                    Spacer()
                    
                    // Right column: Discount badge + Button (centered vertically)
                    VStack(spacing: 8) {
                        // Discount badge
                        Text("Opp til 30%")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(TV2Theme.Colors.background)
                            )
                        
                        // Button
                        HStack(spacing: 6) {
                            Text("Se alle tilbud")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(TV2Theme.Colors.primary)
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .frame(height: 160)
            .cornerRadius(TV2Theme.CornerRadius.medium)
            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(ScaleButtonStyle())
        .onAppear {
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    // MARK: - Background
    
    private var backgroundLayer: some View {
        ZStack(alignment: .leading) {
                // Background with image and overlays
                ZStack {
                    // Background image (football field)
                    Image("football_field_bg")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                    
                    // Dark overlay para legibilidad
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.4),
                            Color.black.opacity(0.2)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                }
                .clipped()
        }
    }
    
    
    // MARK: - Analog Countdown
    
    private var analogCountdown: some View {
        let days = Int(timeRemaining) / 86400
        let hours = (Int(timeRemaining) % 86400) / 3600
        let minutes = (Int(timeRemaining) % 3600) / 60
        let seconds = Int(timeRemaining) % 60
        
        return HStack(spacing: 4) {
            // Días
            if days > 0 {
                CountdownUnit(value: days, label: days == 1 ? "dag" : "dager")
            }
            
            // Horas
            if days > 0 || hours > 0 {
                CountdownUnit(value: hours, label: hours == 1 ? "time" : "timer")
            }
            
            // Minutos
            CountdownUnit(value: minutes, label: "min")
            
            // Segundos
            CountdownUnit(value: seconds, label: "sek")
        }
        .padding(.vertical, 3)
    }
    
    // MARK: - Countdown Logic
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                timer?.invalidate()
            }
        }
    }
}

// MARK: - Scale Button Style
/// Adds a subtle scale animation on tap
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

#Preview {
    ZStack {
        TV2Theme.Colors.background
            .ignoresSafeArea()
        
        VStack(spacing: 20) {
            // Version for NavigationLink (without button)
            OfferBannerView()
                .padding(.horizontal, TV2Theme.Spacing.md)
            
            // Version with button
            OfferBanner {
                print("Banner tapped!")
            }
            .padding(.horizontal, TV2Theme.Spacing.md)
        }
    }
    .preferredColorScheme(.dark)
}
