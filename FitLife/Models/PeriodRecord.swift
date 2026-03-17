import Foundation
import SwiftData

@Model
final class PeriodRecord {
    var id: UUID
    var date: Date
    var note: String?

    init(id: UUID = UUID(), date: Date = .now, note: String? = nil) {
        self.id = id
        self.date = date
        self.note = note
    }
}
