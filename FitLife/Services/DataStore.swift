import Foundation
import SwiftData
import SwiftUI

@MainActor
class DataStore: ObservableObject {

    let modelContainer: ModelContainer

    init() {
        do {
            let schema = Schema([
                WeightRecord.self,
                FoodRecord.self,
                MoodRecord.self,
                SleepRecord.self
            ])
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            self.modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create ModelContainer: \(error.localizedDescription)")
        }
    }

    /// Convenience accessor for the main model context.
    var context: ModelContext {
        modelContainer.mainContext
    }

    // MARK: - Weight Records

    /// Returns weight records from the last `days` days, sorted by date descending.
    func weightRecords(days: Int) -> [WeightRecord] {
        let calendar = Calendar.current
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: Date())) else {
            return []
        }

        let predicate = #Predicate<WeightRecord> { record in
            record.date >= startDate
        }

        var descriptor = FetchDescriptor<WeightRecord>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = nil

        do {
            return try context.fetch(descriptor)
        } catch {
            print("Failed to fetch weight records: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Food Records

    /// Returns food records for a specific date.
    func foodRecords(for date: Date) -> [FoodRecord] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }

        let predicate = #Predicate<FoodRecord> { record in
            record.date >= startOfDay && record.date < endOfDay
        }

        let descriptor = FetchDescriptor<FoodRecord>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )

        do {
            return try context.fetch(descriptor)
        } catch {
            print("Failed to fetch food records: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Mood

    /// Returns today's mood record.
    func todayMood() -> MoodRecord? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return nil
        }

        let predicate = #Predicate<MoodRecord> { record in
            record.date >= startOfDay && record.date < endOfDay
        }

        var descriptor = FetchDescriptor<MoodRecord>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        do {
            return try context.fetch(descriptor).first
        } catch {
            print("Failed to fetch mood record: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Sleep

    /// Returns sleep record for a specific date.
    func sleepRecord(for date: Date) -> SleepRecord? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return nil
        }

        let predicate = #Predicate<SleepRecord> { record in
            record.date >= startOfDay && record.date < endOfDay
        }

        var descriptor = FetchDescriptor<SleepRecord>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        do {
            return try context.fetch(descriptor).first
        } catch {
            print("Failed to fetch sleep record: \(error.localizedDescription)")
            return nil
        }
    }
}
