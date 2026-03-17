import Foundation
import SwiftData

@Model
final class DrinkRecord {
    var id: UUID
    var date: Date
    var type: String  // 水、咖啡、豆浆、牛奶、苹果醋、自定义
    var amount: Int    // ml

    init(id: UUID = UUID(), date: Date = .now, type: String = "水", amount: Int = 250) {
        self.id = id
        self.date = date
        self.type = type
        self.amount = amount
    }

    static let defaultTypes = ["水", "咖啡", "豆浆", "牛奶", "苹果醋", "茶", "果汁"]
}
