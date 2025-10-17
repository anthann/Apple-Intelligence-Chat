//
//  SettingsView.swift
//  Apple Intelligence Chat
//
//  Created by Pallav Agarwal on 6/9/25.
//

import SwiftUI

/// App-wide settings stored in UserDefaults
enum AppSettings {
    @AppStorage("useStreaming") static var useStreaming: Bool = true
    @AppStorage("temperature") static var temperature: Double = 0.7
    @AppStorage("systemInstructions") static var systemInstructions: String = """
    You are a WeStore Cafe assistant. Help customers order coffee using these tools:

    **Tools:**
    - get_menu: Show coffee menu with prices and options
    - add_to_cart: Add items with temperature/sweetness preferences  
    - view_cart: Show cart contents and total

    **Options:**
    - Temperature: hot/iced
    - Sweetness: no_sugar/light/regular/extra

    **Workflow:**
    1. Show menu when customers ask about coffee
    2. Ask: coffee choice → temperature → sweetness → quantity
    3. Use add_to_cart tool
    4. Offer to view cart or add more items

    **Guidelines:**
    - Ask one question at a time
    - Confirm choices before adding to cart
    - Be friendly and professional in English
    """
}

/// Settings screen for configuring AI behavior
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    var onDismiss: (() -> Void)?
    
    @AppStorage("useStreaming") private var useStreaming = AppSettings.useStreaming
    @AppStorage("temperature") private var temperature = AppSettings.temperature
    @AppStorage("systemInstructions") private var systemInstructions = AppSettings.systemInstructions
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Generation") {
                    Toggle("Stream Responses", isOn: $useStreaming)
                    VStack(alignment: .leading) {
                        Text("Temperature: \(temperature, specifier: "%.2f")")
                        Slider(value: $temperature, in: 0.0...2.0, step: 0.1)
                    }
                    .padding(.vertical, 4)
                }
                
                Section("System Instructions") {
                    TextEditor(text: $systemInstructions)
                        .frame(minHeight: 100)
                        .font(.body)
                }
            }
            .navigationTitle("Settings")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onDisappear { onDismiss?() }
    }
}
