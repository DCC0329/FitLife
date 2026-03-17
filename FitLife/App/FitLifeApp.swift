import SwiftUI
import SwiftData

@main
struct FitLifeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [WeightRecord.self, FoodRecord.self, MoodRecord.self, SleepRecord.self, ExerciseRecord.self, PeriodRecord.self, DrinkRecord.self])
    }
}
