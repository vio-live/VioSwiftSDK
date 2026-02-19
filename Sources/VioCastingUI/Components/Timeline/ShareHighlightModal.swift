//
//  ShareHighlightModal.swift
//  Viaplay
//
//  Modal for sharing/downloading highlights
//

import SwiftUI

struct ShareHighlightModal: View {
    let highlightTitle: String
    let videoURL: URL
    let onDismiss: () -> Void
    
    @State private var showDownloadSuccess = false
    @State private var showShareSheet = false
    
    var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
            
            // Modal content
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 16) {
                    // Handle
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 40, height: 4)
                        .padding(.top, 12)
                    
                    // Title
                    VStack(spacing: 4) {
                        Text("Del høydepunkt")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text(highlightTitle)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 20)
                    
                    Divider()
                        .background(Color.white.opacity(0.2))
                        .padding(.horizontal, 20)
                    
                    // Share options
                    VStack(spacing: 12) {
                        // Share to social
                        ShareOptionButton(
                            icon: "square.and.arrow.up.fill",
                            title: "Del på sosiale medier",
                            subtitle: "Facebook, X, Instagram",
                            color: Color(red: 0.96, green: 0.08, blue: 0.42),
                            action: {
                                showShareSheet = true
                            }
                        )
                        
                        // Download
                        ShareOptionButton(
                            icon: "arrow.down.circle.fill",
                            title: "Last ned video",
                            subtitle: "Lagre til enheten din",
                            color: .blue,
                            action: {
                                downloadVideo()
                            }
                        )
                        
                        // Copy link
                        ShareOptionButton(
                            icon: "link.circle.fill",
                            title: "Kopier lenke",
                            subtitle: "Del lenken direkte",
                            color: .purple,
                            action: {
                                copyLink()
                            }
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    
                    // Cancel button
                    Button(action: onDismiss) {
                        Text("Avbryt")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.1))
                            )
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(hex: "1F1E26"))
                )
                .padding(.horizontal, 8)
            }
            
            // Success message
            if showDownloadSuccess {
                VStack {
                    Spacer()
                    
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.green)
                        
                        Text("Video lastet ned!")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.8))
                    )
                    .padding(.bottom, 100)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = URL(string: "https://viaplay.com/share/highlight/\(highlightTitle)") {
                ShareSheet(items: [url])
            }
        }
    }
    
    // MARK: - Actions
    
    private func downloadVideo() {
        print("📥 Downloading video: \(videoURL)")
        
        // Simulate download
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showDownloadSuccess = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showDownloadSuccess = false
            }
            onDismiss()
        }
        
        // TODO: Actual download implementation
        // URLSession.shared.downloadTask(with: videoURL) { ... }
    }
    
    private func copyLink() {
        let link = "https://viaplay.com/highlight/\(highlightTitle)"
        UIPasteboard.general.string = link
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showDownloadSuccess = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showDownloadSuccess = false
            }
            onDismiss()
        }
    }
}

// MARK: - Share Option Button

private struct ShareOptionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 46, height: 46)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(color)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ShareHighlightModal(
        highlightTitle: "MÅL: A. Diallo",
        videoURL: URL(string: "https://example.com/video.mp4")!,
        onDismiss: {}
    )
}
