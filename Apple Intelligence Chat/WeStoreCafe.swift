import FoundationModels
import Foundation
import Combine

// MARK: - Data Models

/// Coffee temperature options
enum CoffeeTemperature: String, CaseIterable, Codable {
    case hot = "hot"
    case iced = "iced"
    
    var displayName: String {
        switch self {
        case .hot: return "Hot"
        case .iced: return "Iced"
        }
    }
}

/// Sweetness level options
enum SweetnessLevel: String, CaseIterable, Codable {
    case noSugar = "no_sugar"
    case light = "light"
    case regular = "regular"
    case extra = "extra"
    
    var displayName: String {
        switch self {
        case .noSugar: return "No Sugar"
        case .light: return "Light"
        case .regular: return "Regular"
        case .extra: return "Extra"
        }
    }
}

/// Coffee beverage item
struct CoffeeItem: Codable {
    let id: String
    let name: String
    let price: Double
    let description: String
    let availableTemperatures: [CoffeeTemperature]
    let availableSweetness: [SweetnessLevel]
}

/// Item in shopping cart
struct CartItem: Codable {
    let coffeeItem: CoffeeItem
    let temperature: CoffeeTemperature
    let sweetness: SweetnessLevel
    var quantity: Int
    
    var totalPrice: Double {
        return coffeeItem.price * Double(quantity)
    }
}

/// Shopping cart
struct ShoppingCart: Codable {
    var items: [CartItem] = []
    
    var totalAmount: Double {
        return items.reduce(0) { $0 + $1.totalPrice }
    }
    
    mutating func addItem(_ item: CartItem) {
        // Check if item with same configuration already exists
        if let existingIndex = items.firstIndex(where: { 
            $0.coffeeItem.id == item.coffeeItem.id && 
            $0.temperature == item.temperature && 
            $0.sweetness == item.sweetness 
        }) {
            items[existingIndex].quantity += item.quantity
        } else {
            items.append(item)
        }
    }
}

// MARK: - Mock Data

/// WeStore Cafe coffee menu
class WeStoreCafeMenu {
    static let shared = WeStoreCafeMenu()
    
    let menuItems: [CoffeeItem] = [
        CoffeeItem(
            id: "americano",
            name: "Americano",
            price: 25.0,
            description: "Classic Americano coffee with rich flavor",
            availableTemperatures: [.hot, .iced],
            availableSweetness: [.noSugar, .light, .regular]
        ),
        CoffeeItem(
            id: "latte",
            name: "Latte",
            price: 35.0,
            description: "Perfect blend of rich milk and coffee",
            availableTemperatures: [.hot, .iced],
            availableSweetness: [.noSugar, .light, .regular, .extra]
        ),
        CoffeeItem(
            id: "cappuccino",
            name: "Cappuccino",
            price: 32.0,
            description: "Classic combination of rich foam and coffee",
            availableTemperatures: [.hot],
            availableSweetness: [.noSugar, .light, .regular]
        ),
        CoffeeItem(
            id: "mocha",
            name: "Mocha",
            price: 38.0,
            description: "Sweet encounter of chocolate and coffee",
            availableTemperatures: [.hot, .iced],
            availableSweetness: [.light, .regular, .extra]
        ),
        CoffeeItem(
            id: "espresso",
            name: "Espresso",
            price: 20.0,
            description: "Authentic Italian espresso coffee",
            availableTemperatures: [.hot],
            availableSweetness: [.noSugar]
        )
    ]
    
    private init() {}
}

// MARK: - Shopping Cart Manager

class ShoppingCartManager: ObservableObject {
    @Published var cart = ShoppingCart()
    
    static let shared = ShoppingCartManager()
    
    private init() {}
}

// MARK: - Tools

/// Tool 1: Get coffee shop menu
struct WeStoreCafeMenuTool: Tool {
    let name = "get_menu"
    let description = "Get the complete WeStore Cafe coffee menu including prices, descriptions and customization options"
    
    typealias Output = String
    
    @Generable
    struct Arguments {
        // No parameters needed
    }
    
    func call(arguments: Arguments) async throws -> String {
        let menu = await WeStoreCafeMenu.shared.menuItems
        
        var menuText = "🏪 WeStore Cafe Menu\n\n"
        
        for item in menu {
            menuText += "☕ \(item.name)\n"
            menuText += "💰 Price: $\(String(format: "%.0f", item.price))\n"
            menuText += "📝 Description: \(item.description)\n"
            menuText += "🌡️ Temperature Options: \(item.availableTemperatures.map { $0.rawValue }.joined(separator: ", "))\n"
            menuText += "🍯 Sweetness Options: \(item.availableSweetness.map { $0.rawValue }.joined(separator: ", "))\n"
            menuText += "🆔 Item ID: \(item.id)\n\n"
        }
        
        menuText += "💡 Tip: Use item ID, temperature and sweetness options to place orders"
        
        return menuText
    }
}

/// Tool 2: Add beverage to cart
struct AddToCartTool: Tool {
    let name = "add_to_cart"
    let description = "Add specified coffee beverage to shopping cart"
    
    typealias Output = String
    
    @Generable
    struct Arguments {
        let itemId: String
        let temperature: String
        let sweetness: String
        let quantity: Int
    }
    
    func call(arguments: Arguments) async throws -> String {
        // Find the item
        guard let coffeeItem = await WeStoreCafeMenu.shared.menuItems.first(where: { $0.id == arguments.itemId }) else {
            return "❌ Error: Cannot find beverage with item ID '\(arguments.itemId)'"
        }
        
        // Convert string to enum type
        guard let temperature = CoffeeTemperature(rawValue: arguments.temperature) else {
            return "❌ Error: Invalid temperature option '\(arguments.temperature)'"
        }
        
        guard let sweetness = SweetnessLevel(rawValue: arguments.sweetness) else {
            return "❌ Error: Invalid sweetness option '\(arguments.sweetness)'"
        }
        
        // Validate temperature option
        guard coffeeItem.availableTemperatures.contains(temperature) else {
            return "❌ Error: '\(coffeeItem.name)' does not support '\(temperature.displayName)' option"
        }
        
        // Validate sweetness option
        guard coffeeItem.availableSweetness.contains(sweetness) else {
            return "❌ Error: '\(coffeeItem.name)' does not support '\(sweetness.displayName)' option"
        }
        
        // Validate quantity
        guard arguments.quantity > 0 else {
            return "❌ Error: Quantity must be greater than 0"
        }
        
        // Create cart item
        let cartItem = CartItem(
            coffeeItem: coffeeItem,
            temperature: temperature,
            sweetness: sweetness,
            quantity: arguments.quantity
        )
        
        // Add to cart
        await ShoppingCartManager.shared.cart.addItem(cartItem)
        
        let totalPrice = cartItem.totalPrice
        let result = "✅ Successfully added to cart!\n\n" +
               "☕ Item: \(coffeeItem.name)\n" +
               "🌡️ Temperature: \(temperature.displayName)\n" +
               "🍯 Sweetness: \(sweetness.displayName)\n" +
               "📦 Quantity: \(arguments.quantity)\n" +
               "💰 Subtotal: $\(String(format: "%.0f", totalPrice))\n" +
               "🛒 Cart Total: $\(String(format: "%.0f", await ShoppingCartManager.shared.cart.totalAmount))"
        
        return result
    }
}

/// Tool 3: View cart contents and total amount
struct ViewCartTool: Tool {
    let name = "view_cart"
    let description = "View all items in shopping cart and total amount"
    
    typealias Output = String
    
    @Generable
    struct Arguments {
        // No parameters needed
    }
    
    func call(arguments: Arguments) async throws -> String {
        let cart = await ShoppingCartManager.shared.cart
        
        if cart.items.isEmpty {
            return "🛒 Cart is empty\n\n💡 Tip: Use the menu tool to view available items, then add them to cart"
        }
        
        var cartText = "🛒 WeStore Cafe Cart\n\n"
        
        for (index, item) in cart.items.enumerated() {
            cartText += "\(index + 1). ☕ \(item.coffeeItem.name)\n"
            cartText += "   🌡️ Temperature: \(item.temperature.displayName)\n"
            cartText += "   🍯 Sweetness: \(item.sweetness.displayName)\n"
            cartText += "   📦 Quantity: \(item.quantity)\n"
            cartText += "   💰 Unit Price: $\(String(format: "%.0f", item.coffeeItem.price))\n"
            cartText += "   💰 Subtotal: $\(String(format: "%.0f", item.totalPrice))\n\n"
        }
        
        cartText += "💳 Total Amount: $\(String(format: "%.0f", cart.totalAmount))\n"
        cartText += "📊 Item Types: \(cart.items.count) types\n"
        cartText += "📦 Total Quantity: \(cart.items.reduce(0) { $0 + $1.quantity }) items"
        
        return cartText
    }
}
