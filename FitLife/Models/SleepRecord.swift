import Foundation
import SwiftData

@Model
final class SleepRecord {
    var id: UUID
    var date: Date
    var bedTime: Date
    var wakeTime: Date
    var quality: Int
    var isManual: Bool

    var durationHours: Double {
        wakeTime.timeIntervalSince(bedTime) / 3600.0
    }

    init(
        id: UUID = UUID(),
        date: Date = .now,
        bedTime: Date,
        wakeTime: Date,
        quality: Int = 3,
        isManual: Bool = false
    ) {
        self.id = id
        self.date = date
        self.bedTime = bedTime
        self.wakeTime = wakeTime
        self.quality = min(max(quality, 1), 5)
        self.isManual = isManual
    }
}
