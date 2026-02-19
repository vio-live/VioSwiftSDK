import SwiftUI
import VioUI
import VioCore

/// Demo view showing how to use the dynamic Offer Banner
struct OfferBannerDemo: View {
    @StateObject private var componentManager = ComponentManager.shared
    @State private var showDemo = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Offer Banner Demo")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Campaign ID: \(componentManager.campaignId)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Demo button
            Button("Show Demo Banner") {
                showDemo.toggle()
            }
            .buttonStyle(.borderedProminent)
            
            // Dynamic banner container (now uses config automatically)
            if let bannerConfig = componentManager.activeBanner {
                VOfferBanner(config: bannerConfig)
                    .padding(.horizontal)
            } else if showDemo {
                // Demo banner with hardcoded config
                VOfferBanner(config: demoConfig)
                    .padding(.horizontal)
            } else {
                Text("No active banner")
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .onAppear {
            Task {
                await componentManager.connect()
            }
        }
        .onDisappear {
            componentManager.disconnect()
        }
    }
    
    // Demo configuration for testing
    private var demoConfig: OfferBannerConfig {
        OfferBannerConfig(
            logoUrl: "https://via.placeholder.com/100x30/00FF00/FFFFFF?text=XXL",
            title: "Ukens tilbud",
            subtitle: "Se denne ukes beste tilbud",
            backgroundImageUrl: "https://images.unsplash.com/photo-1574629810360-7efbbe195018?w=800&h=400&fit=crop",
            countdownEndDate: "2025-12-31T23:59:59Z",
            discountBadgeText: "Opp til 30%",
            ctaText: "Se alle tilbud →",
            ctaLink: "https://xxlsports.no/offers",
            overlayOpacity: 0.4
        )
    }
}

/// Alternative: Using the container component (recommended)
struct OfferBannerContainerDemo: View {
    var body: some View {
        VStack {
            Text("Offer Banner Container Demo")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Now uses campaignId from configuration automatically!")
                .font(.caption)
                .foregroundColor(.green)
                .padding(.bottom)
            
            // This automatically handles connection and lifecycle
            // No need to pass campaignId manually anymore
            VOfferBannerContainer()
                .padding(.horizontal)
            
            Spacer()
        }
    }
}

/// Example showing the difference between manual and automatic configuration
struct OfferBannerComparisonDemo: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Offer Banner Configuration Comparison")
                .font(.title)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 16) {
                Text("✅ NEW: Automatic Configuration")
                    .font(.headline)
                    .foregroundColor(.green)
                
                Text("VOfferBannerContainer()")
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                
                Text("• Campaign ID read from vio-config.json")
                Text("• No manual parameters needed")
                Text("• Automatic lifecycle management")
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 16) {
                Text("🔧 Manual Configuration (still supported)")
                    .font(.headline)
                    .foregroundColor(.orange)
                
                Text("VOfferBannerContainer(campaignId: 3)")
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                
                Text("• Manual campaign ID parameter")
                Text("• Explicit configuration")
                Text("• Useful for testing different campaigns")
            }
            
            Spacer()
        }
        .padding()
    }
}

#if DEBUG
struct OfferBannerDemo_Previews: PreviewProvider {
    static var previews: some View {
        OfferBannerDemo()
    }
}
#endif