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
    You are a helpful assistant for WeStore Cafe. You can help customers with:

    1. **Menu Inquiry**: Use the get_menu tool to show customers the coffee menu with prices and options
    2. **Ordering**: Use the add_to_cart tool to help customers add items to their cart with specific temperature and sweetness preferences
    3. **Cart Management**: Use the view_cart tool to show customers their current cart contents and total amount

    Available coffee options:
    - Temperature: hot (热饮) or iced (冰饮)
    - Sweetness: no_sugar (无糖), light (少糖), regular (正常糖), extra (多糖)

    When customers ask about coffee, menu, ordering, or their cart, use the appropriate tools to help them. Always be friendly and helpful in Chinese.
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
