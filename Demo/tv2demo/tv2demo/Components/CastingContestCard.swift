import SwiftUI

/// Versión compacta de contest específica para la vista de casting
struct CastingContestCard: View {
    let contest: ContestEventData
    let onJoin: () -> Void
    let onDismiss: () -> Void
    
    @State private var hasJoined = false
    
    var body: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                Circle()
                    .fill(TV2Theme.Colors.primary.opacity(0.2))
                    .frame(width: 56, height: 56)
                
                Image(systemName: "trophy.fill")
                    .font(.system(size: 24))
                    .foregroundColor(TV2Theme.Colors.primary)
            }
            
            // Contest info
            VStack(alignment: .leading, spacing: 6) {
                Text(contest.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text("Premio: \(contest.prize)")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
                
                Text("Finaliza: \(contest.deadline)")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            // Join button or status
            if hasJoined {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                    Text("Inscrito")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(TV2Theme.Colors.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(TV2Theme.Colors.primary.opacity(0.2))
                )
            } else {
                Button(action: {
                    hasJoined = true
                    onJoin()
                }) {
                    Text("Participar")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(TV2Theme.Colors.primary)
                        )
                }
            }
            
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
        .padding(16)
        .frame(width: 420) // ANCHO FIJO
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.6))
                .background(.ultraThinMaterial)
        )
        .cornerRadius(12)
    }
}

#Preview {
    ZStack {
        Color.black
        
        CastingContestCard(
            contest: ContestEventData(
                id: "1",
                name: "Predice el resultado final",
                prize: "1000 NOK",
                deadline: "18:00",
                maxParticipants: 100,
                campaignLogo: nil
            ),
            onJoin: {},
            onDismiss: {}
        )
        .padding()
    }
}

