import Foundation
import SwiftData

@Model
final class ExerciseRecord {
    var id: UUID
    var date: Date
    var name: String
    var duration: Int // minutes
    var calories: Double

    init(id: UUID = UUID(), date: Date = .now, name: String, duration: Int, calories: Double) {
        self.id = id
        self.date = date
        self.name = name
        self.duration = duration
        self.calories = calories
    }
}
