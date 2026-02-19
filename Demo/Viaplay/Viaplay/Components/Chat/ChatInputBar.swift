//
//  ChatInputBar.swift
//  Viaplay
//
//  Atomic component: Chat input bar for sending messages
//

import SwiftUI

struct ChatInputBar: View {
    @Binding var messageText: String
    @FocusState.Binding var isFocused: Bool
    let onSend: () -> Void
    let onLike: () -> Void
    let currentUserInitial: String
    let currentUserColor: Color
    
    init(
        messageText: Binding<String>,
        isFocused: FocusState<Bool>.Binding,
        currentUserInitial: String = "A",
        currentUserColor: Color = Color(red: 0.96, green: 0.08, blue: 0.42),
        onSend: @escaping () -> Void,
        onLike: @escaping () -> Void = {}
    ) {
        self._messageText = messageText
        self._isFocused = isFocused
        self.currentUserInitial = currentUserInitial
        self.currentUserColor = currentUserColor
        self.onSend = onSend
        self.onLike = onLike
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // User avatar (smaller)
            Circle()
                .fill(
                    LinearGradient(
                        colors: [currentUserColor, currentUserColor.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 28, height: 28)
                .overlay(
                    Text(currentUserInitial)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                )
            
            // Text field
            TextField("Send en melding...", text: $messageText)
                .font(.system(size: 14))
                .foregroundColor(.white)
                .accentColor(currentUserColor)
                .focused($isFocused)
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.1))
                )
                .onSubmit {
                    if !messageText.isEmpty {
                        onSend()
                    }
                }
            
            // Like button (smaller)
            Button(action: onLike) {
                Image(systemName: "hand.thumbsup.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(currentUserColor)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(currentUserColor.opacity(0.2))
                    )
            }
            
            // Send button (smaller)
            Button(action: {
                if !messageText.isEmpty {
                    onSend()
                }
            }) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(messageText.isEmpty ? .white.opacity(0.3) : currentUserColor)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(messageText.isEmpty ? Color.white.opacity(0.1) : currentUserColor.opacity(0.2))
                    )
            }
            .disabled(messageText.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(hex: "1F1E26"))
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State var text = ""
        @FocusState var focused: Bool
        
        var body: some View {
            VStack {
                Spacer()
                ChatInputBar(
                    messageText: $text,
                    isFocused: $focused,
                    onSend: {
                        print("Send: \(text)")
                        text = ""
                    }
                )
            }
            .background(Color.black)
        }
    }
    return PreviewWrapper()
}
