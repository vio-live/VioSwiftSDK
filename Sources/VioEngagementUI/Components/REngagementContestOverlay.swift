//
//  VEngagementContestOverlay.swift
//  VioEngagementUI
//
//  Contest overlay component for engagement system
//  Uses SDK colors from configuration instead of hardcoded values
//

import SwiftUI
import VioCore
import VioDesignSystem

/// Contest overlay component for engagement system
public struct VEngagementContestOverlay: View {
    let name: String
    let prize: String
    let deadline: String?
    let maxParticipants: Int?
    let prizes: [String]?
    let isChatExpanded: Bool
    let onJoin: () -> Void
    let onDismiss: () -> Void
    
    @State private var hasJoined = false
    @State private var showWheel = false
    @State private var wheelRotation: Double = 0
    @State private var finalPrize: String = ""
    @State private var isSpinning = false
    @State private var countdown: Int = 10
    @State private var dragOffset: CGFloat = 0
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.colorScheme) private var colorScheme
    
    private var isLandscape: Bool {
        verticalSizeClass == .compact
    }
    
    private var bottomPadding: CGFloat {
        if isLandscape {
            return isChatExpanded ? 250 : 156
        } else {
            return isChatExpanded ? 250 : 80
        }
    }
    
    private let defaultPrizes = [
        "🎁 Premio Principal",
        "💰 50% Descuento",
        "🎉 Premio Sorpresa",
        "⭐ Vale Regalo",
        "🏆 Premio Especial",
        "🎊 Descuento 30%"
    ]
    
    public init(
        name: String,
        prize: String,
        deadline: String? = nil,
        maxParticipants: Int? = nil,
        prizes: [String]? = nil,
        isChatExpanded: Bool,
        onJoin: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.name = name
        self.prize = prize
        self.deadline = deadline
        self.maxParticipants = maxParticipants
        self.prizes = prizes
        self.isChatExpanded = isChatExpanded
        self.onJoin = onJoin
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        let colors = VioColors.adaptive(for: colorScheme)
        
        VStack(spacing: 0) {
            if isLandscape {
                Spacer()
                HStack(spacing: 0) {
                    Spacer()
                    contestCard(colors: colors)
                        .frame(width: 320)
                        .padding(.trailing, VioSpacing.md)
                        .padding(.bottom, VioSpacing.md)
                        .offset(x: dragOffset)
                        .gesture(dragGesture)
                }
            } else {
                Spacer()
                contestCard(colors: colors)
                    .padding(.horizontal, VioSpacing.md)
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
    
    private func contestCard(colors: AdaptiveColors) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                if showWheel {
                    wheelView(colors: colors)
                } else {
                    contestInfoView(colors: colors)
                }
            }
            .padding(VioSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: VioBorderRadius.large)
                    .fill(colors.surface.opacity(0.4))
                    .background(
                        RoundedRectangle(cornerRadius: VioBorderRadius.large)
                            .fill(.ultraThinMaterial)
                    )
            )
            .shadow(color: .black.opacity(0.6), radius: 20, x: 0, y: 8)
        }
    }
    
    private func contestInfoView(colors: AdaptiveColors) -> some View {
        VStack(spacing: VioSpacing.md) {
            VEngagementDragIndicator()
            
            HStack {
                VEngagementSponsorBadge()
                Spacer()
            }
            .padding(.horizontal, VioSpacing.sm)
            .padding(.top, 4)
            
            Text(name)
                .font(.system(size: isLandscape ? 16 : 18, weight: .bold))
                .foregroundColor(colors.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            
            VStack(spacing: 6) {
                Text("PREMIER")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(colors.textSecondary)
                
                Text(prize)
                    .font(.system(size: isLandscape ? 13 : 14, weight: .semibold))
                    .foregroundColor(colors.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            .padding(.vertical, VioSpacing.xs)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: VioBorderRadius.medium)
                    .fill(colors.surfaceSecondary.opacity(0.5))
            )
            
            if deadline != nil || maxParticipants != nil {
                VStack(spacing: VioSpacing.xs) {
                    if let deadline = deadline {
                        HStack {
                            Text("Frist: \(deadline)")
                                .font(.system(size: 12))
                                .foregroundColor(colors.textSecondary)
                            Spacer()
                        }
                    }
                    
                    if let maxParticipants = maxParticipants {
                        HStack {
                            Text("Maks deltakere: \(maxParticipants)")
                                .font(.system(size: 12))
                                .foregroundColor(colors.textSecondary)
                            Spacer()
                        }
                    }
                }
            }
            
            if hasJoined {
                VStack(spacing: VioSpacing.xs) {
                    Text("Du er med!")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(colors.success)
                    
                    if countdown > 0 {
                        HStack(spacing: VioSpacing.xs) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: colors.primary))
                                .scaleEffect(0.8)
                            
                            Text("Trekking om \(countdown)s...")
                                .font(.system(size: 12))
                                .foregroundColor(colors.textSecondary)
                        }
                    }
                }
                .padding(.vertical, VioSpacing.sm)
            } else {
                Button(action: {
                    hasJoined = true
                    onJoin()
                }) {
                    Text("Bli med!")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(colors.textOnPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, VioSpacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: VioBorderRadius.medium)
                                .fill(colors.primary.opacity(0.8))
                        )
                }
            }
        }
    }
    
    private func wheelView(colors: AdaptiveColors) -> some View {
        let wheelPrizes = prizes ?? defaultPrizes
        
        return VStack(spacing: 20) {
            Text(isSpinning ? "Snurrer..." : "Gratulerer!")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(colors.textPrimary)
            
            ZStack {
                Triangle()
                    .fill(colors.primary)
                    .frame(width: 24, height: 30)
                    .offset(y: -125)
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    .zIndex(10)
                
                Circle()
                    .fill(colors.surfaceSecondary.opacity(0.5))
                    .frame(width: 260, height: 260)
                    .overlay(
                        Circle()
                            .stroke(colors.textPrimary.opacity(0.1), lineWidth: 1)
                    )
                
                ZStack {
                    ForEach(0..<wheelPrizes.count, id: \.self) { index in
                        wheelSegment(index: index, colors: colors)
                    }
                }
                .rotationEffect(.degrees(wheelRotation))
                .frame(width: 250, height: 250)
                
                Circle()
                    .fill(colors.background)
                    .frame(width: 60, height: 60)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [colors.primary, colors.primary.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 3
                            )
                    )
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .frame(width: 280, height: 280)
        }
    }
    
    private func wheelSegment(index: Int, colors: AdaptiveColors) -> some View {
        let wheelPrizes = prizes ?? defaultPrizes
        let angle = 360.0 / Double(wheelPrizes.count)
        let startAngle = angle * Double(index) - 90
        
        return WheelSegmentShape(startAngle: startAngle, angle: angle)
            .fill(segmentColor(index: index, colors: colors))
            .overlay(
                WheelSegmentShape(startAngle: startAngle, angle: angle)
                    .stroke(Color.black.opacity(0.3), lineWidth: 1)
            )
            .overlay(
                Text(wheelPrizes[index])
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(colors.textPrimary)
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                    .rotationEffect(.degrees(startAngle + angle / 2 + 90))
                    .offset(y: -95)
                    .rotationEffect(.degrees(-(startAngle + angle / 2 + 90)))
            )
            .rotationEffect(.degrees(startAngle + angle / 2 + 90))
    }
    
    private func segmentColor(index: Int, colors: AdaptiveColors) -> Color {
        let opacities: [Double] = [0.9, 0.7, 0.8, 0.6, 0.85, 0.75]
        return colors.primary.opacity(opacities[index % opacities.count])
    }
    
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
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            spinWheel()
        }
    }
    
    private func spinWheel() {
        isSpinning = true
        let wheelPrizes = prizes ?? defaultPrizes
        let rotations = Double.random(in: 3...5)
        let finalAngle = Double.random(in: 0...360)
        let totalRotation = (rotations * 360) + finalAngle
        
        withAnimation(.timingCurve(0.17, 0.67, 0.3, 1.0, duration: 4.0)) {
            wheelRotation = totalRotation
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            isSpinning = false
            let normalizedAngle = finalAngle.truncatingRemainder(dividingBy: 360)
            let segmentAngle = 360.0 / Double(wheelPrizes.count)
            let prizeIndex = Int((360 - normalizedAngle) / segmentAngle) % wheelPrizes.count
            finalPrize = wheelPrizes[prizeIndex]
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

// MARK: - Wheel Segment Shape

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
