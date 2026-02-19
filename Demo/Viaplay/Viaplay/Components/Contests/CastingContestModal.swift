//
//  CastingContestModal.swift
//  Viaplay
//
//  Modal component for Casting contest participation
//  Interactive quiz with animated questions and phone number input
//

import SwiftUI
import VioCore

struct CastingContestModal: View {
    let contest: CastingContestEvent
    let onDismiss: () -> Void
    
    @StateObject private var campaignManager = CampaignManager.shared
    @State private var currentQuestionIndex = 0
    @State private var selectedAnswers: [Int: Int] = [:] // questionIndex: optionIndex
    @State private var showPhoneInput = false
    @State private var phoneNumber = ""
    @State private var isSubmitting = false
    
    // Questions for Champions League tickets
    private let championsLeagueQuestions: [QuizQuestion] = [
        QuizQuestion(
            question: "Hvilken klubb har vunnet flest Champions League-titler?",
            options: ["Real Madrid", "Barcelona", "Bayern München"]
        ),
        QuizQuestion(
            question: "I hvilket år ble Champions League opprettet?",
            options: ["1992", "1985", "2000"]
        ),
        QuizQuestion(
            question: "Hvor mange lag deltar i Champions League-gruppespillet?",
            options: ["32", "24", "16"]
        )
    ]
    
    // Questions for gift card (generic match questions)
    private let matchQuestions: [QuizQuestion] = [
        QuizQuestion(
            question: "Hvilket lag scoret første mål i kampen?",
            options: ["Barcelona", "PSG", "Ingen mål ennå"]
        ),
        QuizQuestion(
            question: "Hvor mange gule kort ble det utdelt i første omgang?",
            options: ["2", "1", "0"]
        ),
        QuizQuestion(
            question: "Hvilken spiller scoret det første målet?",
            options: ["A. Diallo", "B. Mbeumo", "Ingen mål"]
        )
    ]
    
    private var questions: [QuizQuestion] {
        contest.contestType == .giveaway ? championsLeagueQuestions : matchQuestions
    }
    
    private var currentQuestion: QuizQuestion? {
        guard currentQuestionIndex < questions.count else { return nil }
        return questions[currentQuestionIndex]
    }
    
    private var allQuestionsAnswered: Bool {
        selectedAnswers.count == questions.count
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with logo
                HStack {
                    // Campaign logo
                    if let logoUrl = campaignManager.currentCampaign?.campaignLogo {
                        AsyncImage(url: URL(string: logoUrl)) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .scaleEffect(0.5)
                                    .frame(width: 60, height: 30)
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxHeight: 30)
                            case .failure:
                                EmptyView()
                            @unknown default:
                                EmptyView()
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Text(contest.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Close button (X)
                    Button(action: {
                        onDismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.1))
                            )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                // Content area
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Contest info
                        VStack(alignment: .leading, spacing: 8) {
                            Text(contest.description)
                                .font(.system(size: 15))
                                .foregroundColor(.white.opacity(0.9))
                            
                            Text(contest.prize)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.orange)
                                .padding(.top, 4)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // Contest image (if available)
                        if let imageAsset = contest.metadata?["imageAsset"] {
                            Image(imageAsset)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity)
                                .cornerRadius(12)
                                .padding(.horizontal, 20)
                                .padding(.top, 8)
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }
                        
                        // Questions section
                        if !showPhoneInput {
                            VStack(alignment: .leading, spacing: 20) {
                                // Progress indicator
                                HStack(spacing: 8) {
                                    ForEach(0..<questions.count, id: \.self) { index in
                                        Circle()
                                            .fill(index <= currentQuestionIndex ? Color.orange : Color.white.opacity(0.2))
                                            .frame(width: 8, height: 8)
                                            .animation(.spring(response: 0.3), value: currentQuestionIndex)
                                    }
                                }
                                .padding(.horizontal, 20)
                                
                                // Current question (animated)
                                if let question = currentQuestion {
                                    VStack(alignment: .leading, spacing: 16) {
                                        Text("Spørsmål \(currentQuestionIndex + 1) av \(questions.count)")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.white.opacity(0.6))
                                        
                                        Text(question.question)
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundColor(.white)
                                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                                        
                                        // Options
                                        VStack(spacing: 12) {
                                            ForEach(0..<question.options.count, id: \.self) { optionIndex in
                                                QuizOptionButton(
                                                    text: question.options[optionIndex],
                                                    isSelected: selectedAnswers[currentQuestionIndex] == optionIndex,
                                                    onTap: {
                                                        handleAnswerSelection(questionIndex: currentQuestionIndex, optionIndex: optionIndex)
                                                    }
                                                )
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)
                                    ))
                                }
                            }
                        } else {
                            // Phone input section
                            PhoneInputView(
                                phoneNumber: $phoneNumber,
                                onSubmit: {
                                    submitContest()
                                },
                                isSubmitting: isSubmitting
                            )
                            .padding(.horizontal, 20)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentQuestionIndex)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showPhoneInput)
    }
    
    private func handleAnswerSelection(questionIndex: Int, optionIndex: Int) {
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Save answer
        selectedAnswers[questionIndex] = optionIndex
        
        // Move to next question after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if questionIndex < questions.count - 1 {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    currentQuestionIndex += 1
                }
            } else {
                // All questions answered, show phone input
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showPhoneInput = true
                }
            }
        }
    }
    
    private func submitContest() {
        guard !phoneNumber.isEmpty else { return }
        
        isSubmitting = true
        
        // Simulate submission
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isSubmitting = false
            print("✅ Contest submitted: \(contest.id), Phone: \(phoneNumber)")
            onDismiss()
        }
    }
}

// MARK: - Quiz Question Model

struct QuizQuestion {
    let question: String
    let options: [String]
}

// MARK: - Quiz Option Button

struct QuizOptionButton: View {
    let text: String
    let isSelected: Bool
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            onTap()
        }) {
            HStack {
                Text(text)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.orange)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.orange.opacity(0.2) : Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.orange : Color.white.opacity(0.2), lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// MARK: - Phone Input View

struct PhoneInputView: View {
    @Binding var phoneNumber: String
    let onSubmit: () -> Void
    let isSubmitting: Bool
    
    @FocusState private var isPhoneFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Skriv inn telefonnummeret ditt")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            Text("Vi kontakter deg hvis du vinner!")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
            
            // Phone input field
            HStack(spacing: 12) {
                Image(systemName: "phone.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.orange)
                
                TextField("+47 123 45 678", text: $phoneNumber)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .keyboardType(.phonePad)
                    .focused($isPhoneFocused)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isPhoneFocused ? Color.orange : Color.white.opacity(0.2), lineWidth: isPhoneFocused ? 2 : 1)
                    )
            )
            .animation(.spring(response: 0.3), value: isPhoneFocused)
            
            // Submit button
            Button(action: {
                onSubmit()
            }) {
                HStack {
                    if isSubmitting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Send inn")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: phoneNumber.isEmpty ? [Color.gray.opacity(0.3), Color.gray.opacity(0.2)] : [Color.orange, Color.orange.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            }
            .disabled(phoneNumber.isEmpty || isSubmitting)
            .animation(.spring(response: 0.3), value: phoneNumber.isEmpty)
        }
        .padding(.top, 20)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isPhoneFocused = true
            }
        }
    }
}
