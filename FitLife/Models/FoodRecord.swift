import Foundation
import SwiftData

@Model
final class FoodRecord {
    var id: UUID
    var date: Date
    var mealTypeRaw: String
    var foodName: String
    var weight: Double = 100   // 克重，默认100g
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var fiber: Double
    var waterMl: Double
    var imageData: Data?

    var mealType: MealType {
        get { MealType(rawValue: mealTypeRaw) ?? .breakfast }
        set { mealTypeRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        date: Date = .now,
        mealType: MealType = .breakfast,
        foodName: String,
        weight: Double = 100,
        calories: Double = 0,
        protein: Double = 0,
        carbs: Double = 0,
        fat: Double = 0,
        fiber: Double = 0,
        waterMl: Double = 0,
        imageData: Data? = nil
    ) {
        self.id = id
        self.date = date
        self.mealTypeRaw = mealType.rawValue
        self.foodName = foodName
        self.weight = weight
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.fiber = fiber
        self.waterMl = waterMl
        self.imageData = imageData
    }
}

enum MealType: String, Codable, CaseIterable {
    case breakfast
    case lunch
    case dinner
    case snack

    var label: String {
        switch self {
        case .breakfast: return "早餐"
        case .lunch: return "午餐"
        case .dinner: return "晚餐"
        case .snack: return "加餐"
        }
    }
}
