import SwiftUI
import VioCore

/// Custom loader component using Vio logo SVG
/// Provides multiple animation styles for loading states
public struct VCustomLoader: View {
    
    public enum LoaderStyle {
        case rotate
        case pulse
        case bounce
        case fade
    }
    
    let style: LoaderStyle
    let size: CGFloat
    let color: Color
    let speed: Double
    
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 1.0
    @State private var bounceOffset: CGFloat = 0
    
    @SwiftUI.Environment(\.colorScheme) private var colorScheme
    
    private var adaptiveColors: AdaptiveColors {
        VioColors.adaptive(for: colorScheme)
    }
    
    public init(
        style: LoaderStyle = .rotate,
        size: CGFloat = 48,
        color: Color? = nil,
        speed: Double = 1.0
    ) {
        self.style = style
        self.size = size
        // Default to subtle gray if no color specified
        self.color = color ?? Color.gray.opacity(0.4)
        self.speed = speed
    }
    
    public var body: some View {
        Group {
            switch style {
            case .rotate:
                rotatingLoader
            case .pulse:
                pulsingLoader
            case .bounce:
                bouncingLoader
            case .fade:
                fadingLoader
            }
        }
        .frame(width: size, height: size)
    }
    
    // MARK: - Rotating Loader (default)
    private var rotatingLoader: some View {
        vioLogoPath
            .fill(color)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                // Start rotation immediately
                rotation = 0
                withAnimation(
                    Animation.linear(duration: 1.5 / speed)
                        .repeatForever(autoreverses: false)
                ) {
                    rotation = 360
                }
            }
    }
    
    // MARK: - Pulsing Loader
    private var pulsingLoader: some View {
        vioLogoPath
            .fill(color)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(
                    Animation.easeInOut(duration: 1.0 / speed)
                        .repeatForever(autoreverses: true)
                ) {
                    scale = 1.2
                    opacity = 0.6
                }
            }
    }
    
    // MARK: - Bouncing Loader
    private var bouncingLoader: some View {
        vioLogoPath
            .fill(color)
            .offset(y: bounceOffset)
            .onAppear {
                withAnimation(
                    Animation.easeInOut(duration: 0.8 / speed)
                        .repeatForever(autoreverses: true)
                ) {
                    bounceOffset = -size * 0.2
                }
            }
    }
    
    // MARK: - Fading Loader
    private var fadingLoader: some View {
        vioLogoPath
            .fill(color)
            .opacity(opacity)
            .onAppear {
                withAnimation(
                    Animation.easeInOut(duration: 1.2 / speed)
                        .repeatForever(autoreverses: true)
                ) {
                    opacity = 0.3
                }
            }
    }
    
    // MARK: - Vio Logo Path (from SVG)
    private var vioLogoPath: Path {
        // SVG viewBox: "0 0 45 48"
        // Logo dimensions: 45 wide x 48 tall
        // Scale to fit within the desired size while maintaining aspect ratio
        let svgWidth: CGFloat = 45
        let svgHeight: CGFloat = 48
        let scaleFactor = size / max(svgWidth, svgHeight)
        
        // Calculate offset to center the logo
        let scaledWidth = svgWidth * scaleFactor
        let scaledHeight = svgHeight * scaleFactor
        let offsetX = (size - scaledWidth) / 2
        let offsetY = (size - scaledHeight) / 2
        
        var path = Path()
        
        // First rectangle: M44.2932 47.0859H22.1466V23.5429H44.2932V47.0859
        // This creates a rectangle from (22.1466, 23.5429) to (44.2932, 47.0859)
        let rect1 = CGRect(
            x: offsetX + 22.1466 * scaleFactor,
            y: offsetY + 23.5429 * scaleFactor,
            width: (44.2932 - 22.1466) * scaleFactor,
            height: (47.0859 - 23.5429) * scaleFactor
        )
        path.addRect(rect1)
        
        // Second rectangle: M22.1466 0H0V23.5429H22.1466V0
        // This creates a rectangle from (0, 0) to (22.1466, 23.5429)
        let rect2 = CGRect(
            x: offsetX + 0,
            y: offsetY + 0,
            width: 22.1466 * scaleFactor,
            height: 23.5429 * scaleFactor
        )
        path.addRect(rect2)
        
        return path
    }
}

// MARK: - View Extension for Easy Usage
extension View {
    /// Apply custom Vio loader overlay
    public func vioLoader(
        style: VCustomLoader.LoaderStyle = .rotate,
        size: CGFloat = 48,
        color: Color? = nil,
        speed: Double = 1.0
    ) -> some View {
        self.overlay(
            VCustomLoader(style: style, size: size, color: color, speed: speed)
        )
    }
}

// MARK: - Preview
#if DEBUG
struct VCustomLoader_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 40) {
            Text("Rotating")
            VCustomLoader(style: .rotate, size: 48)
            
            Text("Pulsing")
            VCustomLoader(style: .pulse, size: 48)
            
            Text("Bouncing")
            VCustomLoader(style: .bounce, size: 48)
            
            Text("Fading")
            VCustomLoader(style: .fade, size: 48)
            
            Text("Custom Color")
            VCustomLoader(style: .rotate, size: 48, color: .blue)
            
            Text("Small Size")
            VCustomLoader(style: .rotate, size: 24)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
    }
}
#endif

