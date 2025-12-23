//
//  ContentView.swift
//  Apple Intelligence Chat
//
//  Created by Pallav Agarwal on 6/9/25.
//

import SwiftUI
import FoundationModels
import Combine

/// Main chat interface view
struct ContentView: View {
    // MARK: - State Properties
    
    // UI State
    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    @State private var isResponding = false
    @State private var showSettings = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var keyboardHeight: CGFloat = 0
    
    // Model State
    @State private var session: LanguageModelSession?
    @State private var streamingTask: Task<Void, Never>?
    @State private var model = SystemLanguageModel.default
    
    // Settings
    @AppStorage("useStreaming") private var useStreaming = AppSettings.useStreaming
    @AppStorage("temperature") private var temperature = AppSettings.temperature
    @AppStorage("systemInstructions") private var systemInstructions = AppSettings.systemInstructions
    
    // Haptics
#if os(iOS)
    private let hapticStreamGenerator = UISelectionFeedbackGenerator()
#endif
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    // Chat Messages ScrollView
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(messages) { message in
                                    MessageView(message: message, isResponding: isResponding)
                                        .id(message.id)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .padding(.bottom, 16)
                        }
                        .onChange(of: messages.last?.text) { _, _ in
                            if let lastMessage = messages.last {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            }
                        }
                        .onChange(of: keyboardHeight) { _, _ in
                            // 当键盘高度变化时，滚动到底部
                            if let lastMessage = messages.last {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // Input Field
                    inputField
                        .padding(.horizontal, 16)
                        .padding(.bottom, max(16, keyboardHeight > 0 ? 0 : 16))
                        .background(Color(UIColor.systemBackground))
                }
            }
            .navigationTitle("Apple Intelligence Chat")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar { toolbarContent }
            .sheet(isPresented: $showSettings) {
                SettingsView {
                    session = nil // Reset session on settings change
                }
            }
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
                handleKeyboardShow(notification: notification)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                handleKeyboardHide()
            }
            .onTapGesture {
                hideKeyboard()
            }
        }
    }
    
    // MARK: - Subviews
    
    /// Input field with send/stop button
    private var inputField: some View {
        HStack(alignment: .center, spacing: 12) {
            TextField("Ask anything", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .frame(minHeight: 36)
                .disabled(isResponding)
                .onSubmit {
                    if !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        handleSendOrStop()
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            
            Button(action: handleSendOrStop) {
                Image(systemName: isResponding ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(isSendButtonDisabled ? Color.gray.opacity(0.6) : .primary)
            }
            .disabled(isSendButtonDisabled)
            .animation(.easeInOut(duration: 0.2), value: isResponding)
            .animation(.easeInOut(duration: 0.2), value: isSendButtonDisabled)
            .frame(width: 44, height: 44)
            .padding(.trailing, 8)
        }
        .glassEffect(.regular.interactive())
    }
    
    private var isSendButtonDisabled: Bool {
        return inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isResponding
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
#if os(iOS)
        ToolbarItem(placement: .navigationBarLeading) {
            Button(action: resetConversation) {
                Label("New Chat", systemImage: "square.and.pencil")
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: { showSettings = true }) {
                Label("Settings", systemImage: "gearshape")
            }
        }
#else
        ToolbarItem {
            Button(action: resetConversation) {
                Label("New Chat", systemImage: "square.and.pencil")
            }
        }
        ToolbarItem {
            Button(action: { showSettings = true }) {
                Label("Settings", systemImage: "gearshape")
            }
        }
#endif
    }
    
    // MARK: - Model Interaction
    
    private func handleSendOrStop() {
        if isResponding {
            stopStreaming()
        } else {
            guard model.isAvailable else {
                showError(message: "The language model is not available. Reason: \(availabilityDescription(for: model.availability))")
                return
            }
            sendMessage()
        }
    }
    
    private func sendMessage() {
        isResponding = true
        let userMessage = ChatMessage(role: .user, text: inputText)
        messages.append(userMessage)
        let prompt = inputText
        inputText = ""
        
        // 收起键盘
        hideKeyboard()
        
        // Add empty assistant message for streaming
        messages.append(ChatMessage(role: .assistant, text: ""))
        
        streamingTask = Task {
            do {
                if session == nil { session = createSession() }
                
                guard let currentSession = session else {
                    showError(message: "Session could not be created.")
                    isResponding = false
                    return
                }
                
                let options = GenerationOptions(temperature: temperature)
                
                if useStreaming {
                    let stream = currentSession.streamResponse(to: prompt, options: options)
                    for try await partialResponse in stream {
#if os(iOS)
                        hapticStreamGenerator.selectionChanged()
#endif
                        updateLastMessage(with: partialResponse.content)
                    }
                } else {
                    let response = try await currentSession.respond(to: prompt, options: options)
                    updateLastMessage(with: response.content)
                }
            } catch is CancellationError {
                // User cancelled generation
            } catch {
                showError(message: "An error occurred: \(error.localizedDescription)")
            }
            
            isResponding = false
            streamingTask = nil
        }
    }
    
    private func stopStreaming() {
        streamingTask?.cancel()
    }
    
    @MainActor
    private func updateLastMessage(with text: String) {
        messages[messages.count - 1].text = text
    }
    
    // MARK: - Session & Helpers
    
    private func createSession() -> LanguageModelSession {
        // 创建 WeStore Cafe 工具
        let menuTool = WeStoreCafeMenuTool()
        let addToCartTool = AddToCartTool()
        let viewCartTool = ViewCartTool()
        
        // 创建带有工具的语言模型会话
        return LanguageModelSession(
            tools: [menuTool, addToCartTool, viewCartTool],
            instructions: systemInstructions
        )
    }
    
    private func resetConversation() {
        stopStreaming()
        messages.removeAll()
        session = nil
    }
    
    private func availabilityDescription(for availability: SystemLanguageModel.Availability) -> String {
        switch availability {
            case .available:
                return "Available"
            case .unavailable(let reason):
                switch reason {
                    case .deviceNotEligible:
                        return "Device not eligible"
                    case .appleIntelligenceNotEnabled:
                        return "Apple Intelligence not enabled in Settings"
                    case .modelNotReady:
                        return "Model assets not downloaded"
                    @unknown default:
                        return "Unknown reason"
                }
            @unknown default:
                return "Unknown availability"
        }
    }
    
    @MainActor
    private func showError(message: String) {
        self.errorMessage = message
        self.showErrorAlert = true
        self.isResponding = false
    }
    
    /// 收起键盘
    private func hideKeyboard() {
#if os(iOS)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
#endif
    }
    
    /// 处理键盘显示
    private func handleKeyboardShow(notification: Notification) {
#if os(iOS)
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
        let keyboardHeight = keyboardFrame.cgRectValue.height
        
        withAnimation(.easeInOut(duration: 0.3)) {
            self.keyboardHeight = keyboardHeight
        }
#endif
    }
    
    /// 处理键盘隐藏
    private func handleKeyboardHide() {
        withAnimation(.easeInOut(duration: 0.3)) {
            self.keyboardHeight = 0
        }
    }
}

#Preview {
    ContentView()
}
