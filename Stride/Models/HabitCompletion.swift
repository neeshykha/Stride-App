import Foundation

struct HabitCompletion: Identifiable, Codable, Hashable {
    let id: UUID
    let habitId: UUID
    let date: Date
    let completedAt: Date
    let subtaskId: UUID?
    var note: String?

    init(habitId: UUID, date: Date, completedAt: Date = Date(), subtaskId: UUID? = nil, note: String? = nil) {
        self.id = UUID()
        self.habitId = habitId
        self.date = Calendar.current.startOfDay(for: date)
        self.completedAt = completedAt
        self.subtaskId = subtaskId
        self.note = note
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        habitId = try container.decode(UUID.self, forKey: .habitId)
        date = try container.decode(Date.self, forKey: .date)
        completedAt = try container.decode(Date.self, forKey: .completedAt)
        subtaskId = try container.decodeIfPresent(UUID.self, forKey: .subtaskId)
        note = try container.decodeIfPresent(String.self, forKey: .note)
    }
}
