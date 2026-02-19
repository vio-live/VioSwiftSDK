//
//  AdminCommentCard.swift
//  Viaplay
//
//  Molecular component: Admin/commentator comment card
//

import SwiftUI

struct AdminCommentCard: View {
    let comment: AdminCommentEvent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                // Viaplay logo badge
                Image(DemoDataManager.shared.brandAsset(for: .icon))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(comment.adminName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Kommentator")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                if comment.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color(red: 0.96, green: 0.08, blue: 0.42))
                }
            }
            
            // Comment text
            Text(comment.comment)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.96, green: 0.08, blue: 0.42).opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(red: 0.96, green: 0.08, blue: 0.42).opacity(0.3), lineWidth: 1)
                )
        )
    }
}

#Preview {
    AdminCommentCard(
        comment: AdminCommentEvent(
            id: "admin-1",
            videoTimestamp: 795,
            adminName: "Magnus Drivenes",
            comment: "Nydelig mål! Dette er Champions League på sitt beste!",
            isPinned: true,
            metadata: nil
        )
    )
    .padding()
    .background(Color(hex: "1B1B25"))
}
