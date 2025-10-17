import FoundationModels
import Foundation
import Combine

// MARK: - Data Models

/// 咖啡温度选项
enum CoffeeTemperature: String, CaseIterable, Codable {
    case hot = "hot"
    case iced = "iced"
    
    var displayName: String {
        switch self {
        case .hot: return "热饮"
        case .iced: return "冰饮"
        }
    }
}

/// 甜度选项
enum SweetnessLevel: String, CaseIterable, Codable {
    case noSugar = "no_sugar"
    case light = "light"
    case regular = "regular"
    case extra = "extra"
    
    var displayName: String {
        switch self {
        case .noSugar: return "无糖"
        case .light: return "少糖"
        case .regular: return "正常糖"
        case .extra: return "多糖"
        }
    }
}

/// 咖啡饮品
struct CoffeeItem: Codable {
    let id: String
    let name: String
    let price: Double
    let description: String
    let availableTemperatures: [CoffeeTemperature]
    let availableSweetness: [SweetnessLevel]
}

/// 购物车中的商品
struct CartItem: Codable {
    let coffeeItem: CoffeeItem
    let temperature: CoffeeTemperature
    let sweetness: SweetnessLevel
    var quantity: Int
    
    var totalPrice: Double {
        return coffeeItem.price * Double(quantity)
    }
}

/// 购物车
struct ShoppingCart: Codable {
    var items: [CartItem] = []
    
    var totalAmount: Double {
        return items.reduce(0) { $0 + $1.totalPrice }
    }
    
    mutating func addItem(_ item: CartItem) {
        // 检查是否已存在相同配置的商品
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

/// WeStore Cafe 的咖啡菜单
class WeStoreCafeMenu {
    static let shared = WeStoreCafeMenu()
    
    let menuItems: [CoffeeItem] = [
        CoffeeItem(
            id: "americano",
            name: "美式咖啡",
            price: 25.0,
            description: "经典美式咖啡，口感浓郁",
            availableTemperatures: [.hot, .iced],
            availableSweetness: [.noSugar, .light, .regular]
        ),
        CoffeeItem(
            id: "latte",
            name: "拿铁咖啡",
            price: 35.0,
            description: "香浓牛奶与咖啡的完美融合",
            availableTemperatures: [.hot, .iced],
            availableSweetness: [.noSugar, .light, .regular, .extra]
        ),
        CoffeeItem(
            id: "cappuccino",
            name: "卡布奇诺",
            price: 32.0,
            description: "丰富的奶泡与咖啡的经典组合",
            availableTemperatures: [.hot],
            availableSweetness: [.noSugar, .light, .regular]
        ),
        CoffeeItem(
            id: "mocha",
            name: "摩卡咖啡",
            price: 38.0,
            description: "巧克力与咖啡的甜蜜邂逅",
            availableTemperatures: [.hot, .iced],
            availableSweetness: [.light, .regular, .extra]
        ),
        CoffeeItem(
            id: "espresso",
            name: "意式浓缩",
            price: 20.0,
            description: "纯正意式浓缩咖啡",
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

/// 工具1: 查询咖啡店菜单
struct WeStoreCafeMenuTool: Tool {
    let name = "get_menu"
    let description = "获取 WeStore Cafe 的完整咖啡菜单，包括价格、描述和可定制选项"
    
    typealias Output = String
    
    @Generable
    struct Arguments {
        // 无需参数
    }
    
    func call(arguments: Arguments) async throws -> String {
        let menu = await WeStoreCafeMenu.shared.menuItems
        
        var menuText = "🏪 WeStore Cafe 菜单\n\n"
        
        for item in menu {
            menuText += "☕ \(item.name)\n"
            menuText += "💰 价格: ¥\(String(format: "%.0f", item.price))\n"
            menuText += "📝 描述: \(item.description)\n"
            menuText += "🌡️ 温度选项: \(item.availableTemperatures.map { $0.rawValue }.joined(separator: ", "))\n"
            menuText += "🍯 甜度选项: \(item.availableSweetness.map { $0.rawValue }.joined(separator: ", "))\n"
            menuText += "🆔 商品ID: \(item.id)\n\n"
        }
        
        menuText += "💡 提示: 使用商品ID、温度选项和甜度选项来订购商品"
        
        return menuText
    }
}

/// 工具2: 添加饮品到购物车
struct AddToCartTool: Tool {
    let name = "add_to_cart"
    let description = "将指定的咖啡饮品添加到购物车"
    
    typealias Output = String
    
    @Generable
    struct Arguments {
        let itemId: String
        let temperature: String
        let sweetness: String
        let quantity: Int
    }
    
    func call(arguments: Arguments) async throws -> String {
        // 查找商品
        guard let coffeeItem = await WeStoreCafeMenu.shared.menuItems.first(where: { $0.id == arguments.itemId }) else {
            return "❌ 错误: 找不到商品ID为 '\(arguments.itemId)' 的饮品"
        }
        
        // 转换字符串为枚举类型
        guard let temperature = CoffeeTemperature(rawValue: arguments.temperature) else {
            return "❌ 错误: 无效的温度选项 '\(arguments.temperature)'"
        }
        
        guard let sweetness = SweetnessLevel(rawValue: arguments.sweetness) else {
            return "❌ 错误: 无效的甜度选项 '\(arguments.sweetness)'"
        }
        
        // 验证温度选项
        guard coffeeItem.availableTemperatures.contains(temperature) else {
            return "❌ 错误: '\(coffeeItem.name)' 不支持 '\(temperature.displayName)' 选项"
        }
        
        // 验证甜度选项
        guard coffeeItem.availableSweetness.contains(sweetness) else {
            return "❌ 错误: '\(coffeeItem.name)' 不支持 '\(sweetness.displayName)' 选项"
        }
        
        // 验证数量
        guard arguments.quantity > 0 else {
            return "❌ 错误: 数量必须大于0"
        }
        
        // 创建购物车项目
        let cartItem = CartItem(
            coffeeItem: coffeeItem,
            temperature: temperature,
            sweetness: sweetness,
            quantity: arguments.quantity
        )
        
        // 添加到购物车
        await ShoppingCartManager.shared.cart.addItem(cartItem)
        
        let totalPrice = cartItem.totalPrice
        let result = "✅ 成功添加到购物车!\n\n" +
               "☕ 商品: \(coffeeItem.name)\n" +
               "🌡️ 温度: \(temperature.displayName)\n" +
               "🍯 甜度: \(sweetness.displayName)\n" +
               "📦 数量: \(arguments.quantity)\n" +
               "💰 小计: ¥\(String(format: "%.0f", totalPrice))\n" +
               "🛒 购物车总金额: ¥\(String(format: "%.0f", await ShoppingCartManager.shared.cart.totalAmount))"
        
        return result
    }
}

/// 工具3: 查看购物车内容和总金额
struct ViewCartTool: Tool {
    let name = "view_cart"
    let description = "查看购物车中的所有商品和总金额"
    
    typealias Output = String
    
    @Generable
    struct Arguments {
        // 无需参数
    }
    
    func call(arguments: Arguments) async throws -> String {
        let cart = await ShoppingCartManager.shared.cart
        
        if cart.items.isEmpty {
            return "🛒 购物车是空的\n\n💡 提示: 使用菜单工具查看可用商品，然后添加到购物车"
        }
        
        var cartText = "🛒 WeStore Cafe 购物车\n\n"
        
        for (index, item) in cart.items.enumerated() {
            cartText += "\(index + 1). ☕ \(item.coffeeItem.name)\n"
            cartText += "   🌡️ 温度: \(item.temperature.displayName)\n"
            cartText += "   🍯 甜度: \(item.sweetness.displayName)\n"
            cartText += "   📦 数量: \(item.quantity)\n"
            cartText += "   💰 单价: ¥\(String(format: "%.0f", item.coffeeItem.price))\n"
            cartText += "   💰 小计: ¥\(String(format: "%.0f", item.totalPrice))\n\n"
        }
        
        cartText += "💳 总金额: ¥\(String(format: "%.0f", cart.totalAmount))\n"
        cartText += "📊 商品种类: \(cart.items.count) 种\n"
        cartText += "📦 总数量: \(cart.items.reduce(0) { $0 + $1.quantity }) 件"
        
        return cartText
    }
}
