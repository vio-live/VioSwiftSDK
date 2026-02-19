import SwiftUI
import VioCore
import VioDesignSystem

public struct DynamicComponentRenderer: View {
    @ObservedObject private var manager: DynamicComponentManager
    
    public init(manager: DynamicComponentManager = .shared) {
        self.manager = manager
    }
    
    public var body: some View {
        ZStack {
            ForEach(manager.activeComponents, id: \.id) { component in
                render(component)
            }
        }
        .animation(.easeInOut, value: manager.activeComponents.map { $0.id })
        .onAppear { print("[DynamicRenderer] onAppear active=\(manager.activeComponents.map { $0.id })") }
        .onChange(of: manager.activeComponents) { newValue in
            print("[DynamicRenderer] Active components changed new=\(newValue.map { $0.id })")
        }
    }
    
    @ViewBuilder
    private func render(_ component: DynamicComponent) -> some View {
        switch component.data {
        case .banner(let data):
            bannerPositioned(data)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(1_000_000)
        case .featuredProduct(let data):
            featuredProductPositioned(data.product, position: data.position)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(90)
        }
    }
}

@ViewBuilder
private func featuredProductPositioned(_ product: Product, position: DynamicComponentPosition?) -> some View {
    GeometryReader { proxy in
        // default position if nil
        let pos = position ?? .bottom
        
        // calculate vertical fraction
        let fraction: CGFloat = {
            switch pos {
            case .top: return 0.09
            case .topCenter: return 0.25
            case .center: return 0.5
            case .bottomCenter: return 0.75
            case .bottom: return 0.95
            case .custom: return 0.0
            }
        }()
        
        FeaturedProductComponentView(product: product)
            .position(
                x: proxy.size.width / 2,
                y: proxy.size.height * fraction
            )
    }
    .edgesIgnoringSafeArea(.all)
}

@ViewBuilder
private func bannerPositioned(_ data: BannerComponentData) -> some View {
    GeometryReader { proxy in
        // safe unwrap
        let position = data.position ?? .top
        
        // calculate fraction
        let fraction: CGFloat = {
            switch position {
            case .top: return 0.09
            case .topCenter: return 0.25
            case .center: return 0.5
            case .bottomCenter: return 0.75
            case .bottom: return 0.95
            case .custom: return 0.0
            }
        }()
        
        BannerComponentView(data: data)
            .position(x: proxy.size.width / 2,
                      y: proxy.size.height * fraction)
    }
    .edgesIgnoringSafeArea(.all)
}

struct BannerComponentView: View {
    let data: BannerComponentData
    @State private var isVisible: Bool = true
    
    var body: some View {
        if isVisible {
            content
                .onAppear {
                    print("[DynamicRenderer] Banner appear title=\(data.title ?? "-") duration=\(String(describing: data.duration))")
                }
                .onDisappear {
                    print("[DynamicRenderer] Banner disappear title=\(data.title ?? "-")")
                }
        }
    }
    
    private var content: some View {
        HStack(spacing: VioSpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                if let title = data.title { Text(title).font(VioTypography.subheadline) }
                if let text = data.text { Text(text).font(VioTypography.caption1) }
            }
            Spacer()
            Button(action: { withAnimation { isVisible = false } }) {
                Image(systemName: "xmark").font(.caption)
            }
        }
        .foregroundColor(VioColors.textPrimary)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: VioBorderRadius.medium)
                .fill(.ultraThinMaterial)
                .shadow(radius: 8)
        )
        .padding(.horizontal, 16)
    }
}

struct BannerContainerView: View {
    let data: BannerComponentData
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            VStack {
                switch data.position {
                case .some(.top), .some(.topCenter):
                    banner(for: data.position!)
                    Spacer()
                case .some(.center):
                    Spacer()
                    banner(for: data.position!)
                    Spacer()
                    
                case .some(.bottom), .some(.bottomCenter):
                    Spacer()
                    banner(for: data.position!)
                    
                case .some(.custom):
                    EmptyView()
                    
                case .none:
                    EmptyView()
                }
            }
            .padding(.vertical, 16)
        }
    }
    
    @ViewBuilder
    private func banner(for position: DynamicComponentPosition) -> some View {
        switch position {
        case .top:
            HStack {
                BannerComponentView(data: data)
                Spacer()
            }
        case .topCenter:
            HStack {
                Spacer()
                BannerComponentView(data: data)
                Spacer()
            }
        case .bottom:
            HStack {
                BannerComponentView(data: data)
                Spacer()
            }
        case .bottomCenter:
            HStack {
                Spacer()
                BannerComponentView(data: data)
                Spacer()
            }
        case .center:
            HStack {
                Spacer()
                BannerComponentView(data: data)
                Spacer()
            }
        default:
            EmptyView()
        }
    }
}

struct FeaturedProductComponentView: View {
    let product: Product
    
    var body: some View {
        HStack(spacing: VioSpacing.md) {
            if let img = product.images.first?.url, let url = URL(string: img) {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: { Color.gray.opacity(0.2) }
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: VioBorderRadius.small))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(product.title).font(VioTypography.subheadline).lineLimit(1)
                Text(product.price.displayAmount).font(VioTypography.caption1)
            }
            Spacer()
        }
        .foregroundColor(VioColors.textPrimary)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: VioBorderRadius.large)
                .fill(.ultraThinMaterial)
                .shadow(radius: 8)
        )
        .padding(.horizontal, 16)
        .onAppear { print("[DynamicRenderer] FeaturedProduct appear id=\(product.id) title=\(product.title)") }
        .onDisappear { print("[DynamicRenderer] FeaturedProduct disappear id=\(product.id)") }
    }
}



