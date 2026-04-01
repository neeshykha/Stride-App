import Foundation

struct Subtask: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

enum ScheduleType: String, Codable, Hashable {
    case weekly
    case interval
}

enum HabitType: String, Codable, Hashable {
    case checkbox
    case tally
    case checklist
}

struct Habit: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var notes: String
    var timeCategory: TimeCategory
    var scheduledDays: Set<DayOfWeek>
    var habitType: HabitType
    var targetCount: Int
    var isArchived: Bool
    var createdAt: Date
    var sortIndex: Int

    // Subtask support
    var subtasks: [Subtask]

    // Interval scheduling
    var scheduleType: ScheduleType
    var intervalDays: Int?
    var intervalStartDate: Date?

    // Workspace
    var workspace: Workspace

    // Note requirement
    var requiresNote: Bool

    init(
        id: UUID = UUID(),
        name: String,
        notes: String = "",
        timeCategory: TimeCategory = .morning,
        scheduledDays: Set<DayOfWeek> = Set(DayOfWeek.allCases),
        habitType: HabitType = .checkbox,
        targetCount: Int = 1,
        isArchived: Bool = false,
        createdAt: Date = Date(),
        sortIndex: Int = 0,
        subtasks: [Subtask] = [],
        scheduleType: ScheduleType = .weekly,
        intervalDays: Int? = nil,
        intervalStartDate: Date? = nil,
        workspace: Workspace = .personal,
        requiresNote: Bool = false
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.timeCategory = timeCategory
        self.scheduledDays = scheduledDays
        self.habitType = habitType
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.sortIndex = sortIndex
        self.subtasks = subtasks
        self.scheduleType = scheduleType
        self.intervalDays = intervalDays
        self.intervalStartDate = intervalStartDate
        self.workspace = workspace
        self.requiresNote = requiresNote

        switch habitType {
        case .checkbox:
            self.targetCount = 1
        case .tally:
            self.targetCount = max(2, targetCount)
        case .checklist:
            self.targetCount = max(1, subtasks.count)
        }
    }

    // Custom decoder for backward compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        notes = try container.decode(String.self, forKey: .notes)
        timeCategory = try container.decode(TimeCategory.self, forKey: .timeCategory)
        scheduledDays = try container.decode(Set<DayOfWeek>.self, forKey: .scheduledDays)
        habitType = try container.decodeIfPresent(HabitType.self, forKey: .habitType) ?? .checkbox
        targetCount = try container.decodeIfPresent(Int.self, forKey: .targetCount) ?? 1
        isArchived = try container.decode(Bool.self, forKey: .isArchived)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        sortIndex = try container.decode(Int.self, forKey: .sortIndex)
        subtasks = try container.decodeIfPresent([Subtask].self, forKey: .subtasks) ?? []
        scheduleType = try container.decodeIfPresent(ScheduleType.self, forKey: .scheduleType) ?? .weekly
        intervalDays = try container.decodeIfPresent(Int.self, forKey: .intervalDays)
        intervalStartDate = try container.decodeIfPresent(Date.self, forKey: .intervalStartDate)
        workspace = try container.decodeIfPresent(Workspace.self, forKey: .workspace) ?? .personal
        requiresNote = try container.decodeIfPresent(Bool.self, forKey: .requiresNote) ?? false
    }
}
