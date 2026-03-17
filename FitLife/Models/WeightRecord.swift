import Foundation
import SwiftData

@Model
final class WeightRecord {
    var id: UUID
    var weight: Double
    var date: Date
    var note: String?
    @Attribute(.externalStorage) var photoData: Data?

    init(id: UUID = UUID(), weight: Double, date: Date = .now, note: String? = nil, photoData: Data? = nil) {
        self.id = id
        self.weight = weight
        self.date = date
        self.note = note
        self.photoData = photoData
    }
}
