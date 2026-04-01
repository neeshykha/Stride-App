import Foundation

enum RecurrenceUnit: String, Codable, Hashable, CaseIterable {
    case day, week, month

    var label: String {
        switch self {
        case .day: "Day"
        case .week: "Week"
        case .month: "Month"
        }
    }

    var pluralLabel: String {
        switch self {
        case .day: "Days"
        case .week: "Weeks"
        case .month: "Months"
        }
    }
}

struct QuickTask: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var date: Date?
    var isCompleted: Bool
    var completedAt: Date?
    var createdAt: Date
    var projectId: UUID?
    var workspace: Workspace
    var requiresNote: Bool
    var completionNote: String?
    var isRecurring: Bool
    var recurrenceInterval: Int?
    var recurrenceUnit: RecurrenceUnit?

    init(
        id: UUID = UUID(),
        name: String,
        date: Date? = nil,
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        createdAt: Date = Date(),
        projectId: UUID? = nil,
        workspace: Workspace = .personal,
        requiresNote: Bool = false,
        completionNote: String? = nil,
        isRecurring: Bool = false,
        recurrenceInterval: Int? = nil,
        recurrenceUnit: RecurrenceUnit? = nil
    ) {
        self.id = id
        self.name = name
        self.date = date.map { Calendar.current.startOfDay(for: $0) }
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.createdAt = createdAt
        self.projectId = projectId
        self.workspace = workspace
        self.requiresNote = requiresNote
        self.completionNote = completionNote
        self.isRecurring = isRecurring
        self.recurrenceInterval = recurrenceInterval
        self.recurrenceUnit = recurrenceUnit
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        date = try container.decodeIfPresent(Date.self, forKey: .date)
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        projectId = try container.decodeIfPresent(UUID.self, forKey: .projectId)
        workspace = try container.decodeIfPresent(Workspace.self, forKey: .workspace) ?? .personal
        requiresNote = try container.decodeIfPresent(Bool.self, forKey: .requiresNote) ?? false
        completionNote = try container.decodeIfPresent(String.self, forKey: .completionNote)
        isRecurring = try container.decodeIfPresent(Bool.self, forKey: .isRecurring) ?? false
        recurrenceInterval = try container.decodeIfPresent(Int.self, forKey: .recurrenceInterval)
        recurrenceUnit = try container.decodeIfPresent(RecurrenceUnit.self, forKey: .recurrenceUnit)
    }
}
