//
//  SportView.swift
//  Viaplay
//
//  Created by Angelo Sepulveda on 27/10/2025.
//

import SwiftUI
import VioCore
import VioUI
import VioCastingUI

struct SportView: View {
    @Binding var selectedTab: Int
    @Binding var showSportView: Bool
    @State private var currentCarouselIndex = 0
    
    private var carouselCards: [CarouselCardData] {
        let items = DemoDataManager.shared.carouselCards
        if items.isEmpty {
            return [
                CarouselCardData(imageUrl: "img1", time: "TONIGHT 20:00", logo: "LA LIGA", title: "Real Madrid - Barcelona", subtitle: "La Liga | 12. runde"),
                CarouselCardData(imageUrl: "img1", time: "TONIGHT 21:30", logo: "PREMIER LEAGUE", title: "Manchester United - Chelsea", subtitle: "Premier League | 12. runde"),
                CarouselCardData(imageUrl: "img1", time: "TOMORROW 19:00", logo: "PREMIER LEAGUE", title: "Liverpool - Arsenal", subtitle: "Premier League | 12. runde")
            ]
        }
        return items.map { CarouselCardData(imageUrl: $0.imageUrl, time: $0.time, logo: $0.logo, title: $0.title, subtitle: $0.subtitle) }
    }
    
    private var liveCardsData: [(logo: String, logoIcon: String, title: String, subtitle: String, time: String, backgroundImage: String?)] {
        let items = DemoDataManager.shared.liveCards
        if items.isEmpty {
            return [
                ("UEFA", "star.fill", "Barcelona - PSG", "Champions League", "15:00", "bg"),
                ("CHALLENGE TOUR", "globe", "Rolex Grand", "European Challenge", "12:00", nil)
            ]
        }
        return items.map { ($0.logo, $0.logoIcon, $0.title, $0.subtitle, $0.time, $0.backgroundImage) }
    }
    
    private var sportClipsData: [(imageUrl: String, time: String, title: String, subtitle: String, isLarge: Bool)] {
        let items = DemoDataManager.shared.sportClips
        if items.isEmpty {
            return [
                ("img1", "00:51", "Haaland ofret sitt for å redde City-poeng", "PREMIER LEAGUE | 2K. OKTOBER", false),
                ("img1", "00:53", "Jørgen Strand Larsen scoring i Premier League", "PREMIER LEAGUE", false)
            ]
        }
        return items.map { ($0.imageUrl, $0.time, $0.title, $0.subtitle, $0.isLarge) }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                // Background
                Color(hex: "1B1B25")
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Vis sendeskjema button
                        Button(action: {}) {
                            HStack {
                                Image(systemName: "calendar")
                                    .font(.system(size: 16))
                                Text("Vis sendeskjema")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color(hex: "302F3F"))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 50)
                        .padding(.bottom, 24)
                        .frame(width: geometry.size.width)
                        
                        // Vår beste sport Section with Carousel
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Vår beste sport")
                                .font(.system(size: 19, weight: .regular))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.top, 24)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            TabView(selection: $currentCarouselIndex) {
                                ForEach(carouselCards.indices, id: \.self) { index in
                                    CarouselCard(data: carouselCards[index], selectedTab: $selectedTab)
                                        .padding(.horizontal, 16)
                                        .tag(index)
                                }
                            }
                            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                            .frame(height: 300)
                        }
                        .frame(width: geometry.size.width)
                        
                        // Live akkurat nå Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Live akkurat nå")
                                .font(.system(size: 19, weight: .regular))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.top, 24)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(liveCardsData.indices, id: \.self) { index in
                                        let item = liveCardsData[index]
                                        LiveSportCard(
                                            selectedTab: $selectedTab,
                                            logo: item.logo,
                                            logoIcon: item.logoIcon,
                                            title: item.title,
                                            subtitle: item.subtitle,
                                            time: item.time,
                                            backgroundImage: item.backgroundImage
                                        )
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                        .frame(width: geometry.size.width)
                        .padding(.bottom, 16)
                        
                        // De beste klippene akkurat nå Section
                        SportSection(
                            title: "De beste klippene akkurat nå",
                            cards: sportClipsData.map { item in
                                SportCard(
                                    selectedTab: $selectedTab,
                                    imageUrl: item.imageUrl,
                                    time: item.time,
                                    title: item.title,
                                    subtitle: item.subtitle,
                                    isLarge: item.isLarge
                                )
                            }
                        )
                        
                        // Populær sport Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Populær sport")
                                .font(.system(size: 17, weight: .regular))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.top, 32)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            HStack(spacing: 8) {
                                PopularSportCard(imageName: "cat1")
                                
                                PopularSportCard(imageName: "cat2")
                                
                                PopularSportCard(imageName: "cat3")
                            }
                            .padding(.horizontal, 16)
                        }
                        .frame(width: geometry.size.width)
                        .padding(.bottom, 16)
                        
                        VStack(alignment: .leading, spacing: 10) {
                                              
                            // Header with title and sponsor badge
                            HStack(alignment: .top, spacing: 12) {
                                // Title
                                Text("Ukens tilbud")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.bottom, 20)
                                Spacer()
                                
                                // Campaign sponsor badge
                                CampaignSponsorBadge(
                                    maxWidth: 80,
                                    maxHeight: 24,
                                    alignment: .leading
                                )
                            }
                            .padding(.top, 24)
                            .padding(.horizontal, 16)
                            // Auto-loads based on VioConfiguration (currency/country)
                            VProductSlider(
                                title: nil,
                                products: nil,
                                categoryId: nil,
                                layout: .cards,
                                showSeeAll: false,
                                maxItems: 12
                            )
                            .padding(.bottom, 8)
                        }
                        .frame(maxWidth: geometry.size.width)
                        
                        // Offer Banner Section
                        ViaplayOfferBannerView()
                            .padding(.horizontal, 16)
                            .padding(.top, 24)
                            .padding(.bottom, 100)
                    }
                }
                .ignoresSafeArea(edges: .top)
                
                // Bottom Navigation
                VStack {
                    Spacer()
                    VCastingBottomNav(selectedTab: $selectedTab)
                        .frame(width: geometry.size.width)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            // Asegurar que el tab esté en 1 cuando aparezca SportView
            selectedTab = 1
        }
    }
}

struct CarouselCardData {
    let imageUrl: String
    let time: String
    let logo: String
    let title: String
    let subtitle: String
}

struct CarouselCard: View {
    let data: CarouselCardData
    @Binding var selectedTab: Int
    
    var body: some View {
        NavigationLink(destination: SportDetailView(
            selectedTab: $selectedTab,
            title: data.title,
            subtitle: data.subtitle,
            imageUrl: data.imageUrl
        )) {
            VStack(alignment: .leading, spacing: 0) {
                // Image section with time badge
                ZStack(alignment: .topLeading) {
                    // Background image
                    Group {
                        if data.imageUrl.hasPrefix("http") {
                            AsyncImage(url: URL(string: data.imageUrl)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Rectangle()
                                    .fill(Color(red: 0.15, green: 0.15, blue: 0.2))
                            }
                        } else {
                            Image(data.imageUrl)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        }
                    }
                    .frame(height: 220)
                    .clipped()
                    .cornerRadius(12, corners: [.topLeft, .topRight])
                    
                    // Time badge - top left
                    Text(data.time)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white)
                        .cornerRadius(5)
                        .padding(12)
                    
                    // LIGUE 1 badge - bottom left overlapping
                    VStack {
                        Spacer()
                        HStack {
                            Text(data.logo)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(hex: "2C2D36"))
                                .cornerRadius(5)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                    }
                }
                .frame(height: 220)
                
                // Info section
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(data.title)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text(data.subtitle)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    // Three dots menu
                    Button(action: {}) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .rotationEffect(.degrees(90))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(Color(hex: "2C2D36"))
                .cornerRadius(12, corners: [.bottomLeft, .bottomRight])
            }
            .background(Color(hex: "2C2D36"))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Extension for corner radius on specific corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

struct SportSection: View {
    let title: String
    let cards: [SportCard]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.top, 32)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if cards.count == 1 && cards[0].isLarge {
                // Large single card
                cards[0]
                    .padding(.horizontal, 16)
            } else {
                // Horizontal scroll for multiple cards
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(cards.indices, id: \.self) { index in
                            cards[index]
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 16)
    }
}

struct SportCard: View {
    @Binding var selectedTab: Int
    let imageUrl: String
    let time: String
    let title: String
    let subtitle: String
    let isLarge: Bool
    
    var body: some View {
        NavigationLink(destination: SportDetailView(
            selectedTab: $selectedTab,
            title: title,
            subtitle: subtitle,
            imageUrl: imageUrl
        )) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    // Image
                    Image(imageUrl)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                    .frame(width: isLarge ? nil : 200, height: isLarge ? 200 : 120)
                    .clipped()
                    .cornerRadius(12)
                    
                    // Time badge
                    Text(time)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(4)
                        .padding(8)
                    
                    // Crown icon centered
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.5))
                            .frame(width: 46, height: 46)
                        
                        Image(systemName: "crown.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                // Info section
                VStack(alignment: .leading, spacing: 4) {
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                            .textCase(.uppercase)
                    }
                    
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                }
                .padding(.top, 8)
            }
            .frame(width: isLarge ? nil : 200)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct LiveSportCard: View {
    @Binding var selectedTab: Int
    let logo: String
    let logoIcon: String
    let title: String
    let subtitle: String
    let time: String
    let backgroundImage: String?
    
    init(selectedTab: Binding<Int>, logo: String, logoIcon: String, title: String, subtitle: String, time: String, backgroundImage: String? = nil) {
        self._selectedTab = selectedTab
        self.logo = logo
        self.logoIcon = logoIcon
        self.title = title
        self.subtitle = subtitle
        self.time = time
        self.backgroundImage = backgroundImage
    }
    
    var body: some View {
        NavigationLink(destination: SportDetailView(
            selectedTab: $selectedTab,
            title: title,
            subtitle: subtitle,
            imageUrl: "img1"
        )) {
            ZStack(alignment: .topLeading) {
                // Background card
                if let backgroundImage = backgroundImage {
                    Image(backgroundImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 310, height: 190)
                        .clipped()
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black.opacity(0.4))
                        )
                        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: "2C2D36"))
                        .frame(width: 310, height: 190)
                        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                
                // LIVE badge
                Text("LIVE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(red: 0.96, green: 0.08, blue: 0.42))
                    .cornerRadius(5)
                    .padding(12)
                
                if backgroundImage == nil {
                    // Center content - only show when there's no background image
                    VStack(spacing: 8) {
                        // Logo with icon - centered
                        HStack(spacing: 6) {
                            Image(systemName: logoIcon)
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.yellow)
                            
                            VStack(alignment: .leading, spacing: 0) {
                                Text(logo.components(separatedBy: " ").first ?? "")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(.white)
                                
                                if let secondPart = logo.components(separatedBy: " ").dropFirst().first {
                                    Text(secondPart)
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        
                        // Title
                        Text(title)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                        
                        // Subtitle
                        Text(subtitle)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 30)
                    
                    // Bottom content - only show when there's no background image
                    VStack {
                        Spacer()
                        
                        HStack {
                            // Time
                            Text(time)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            // Ellipsis menu
                            Button(action: {}) {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                    .rotationEffect(.degrees(90))
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                }
                
                // Progress bar - always show
                VStack {
                    Spacer()
                    
                    GeometryReader { progressGeometry in
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(Color(red: 0.96, green: 0.08, blue: 0.42))
                                .frame(width: progressGeometry.size.width * 0.25, height: 3)
                                .cornerRadius(1.5)
                            
                            Rectangle()
                                .fill(Color.white.opacity(0.3))
                                .frame(height: 3)
                                .cornerRadius(1.5)
                        }
                        .frame(height: 3)
                    }
                    .frame(height: 3)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
            }
            .frame(width: 310, height: 190)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct PopularSportCard: View {
    let imageName: String
    
    var body: some View {
        Image(imageName)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(maxWidth: 120)
            .frame(height: 200)
            .clipped()
            .cornerRadius(10)
    }
}

#Preview {
    SportView(selectedTab: .constant(0), showSportView: .constant(true))
}

