import Foundation

final class StorageService: @unchecked Sendable {
    static let shared = StorageService()

    private let fileManager = FileManager.default

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private var appSupportURL: URL {
        let url = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Stride", isDirectory: true)
        if !fileManager.fileExists(atPath: url.path) {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    private var habitsURL: URL {
        appSupportURL.appendingPathComponent("habits.json")
    }

    private var completionsURL: URL {
        appSupportURL.appendingPathComponent("completions.json")
    }

    func loadHabits() -> [Habit] {
        load(from: habitsURL) ?? []
    }

    func saveHabits(_ habits: [Habit]) {
        save(habits, to: habitsURL)
    }

    func loadCompletions() -> [HabitCompletion] {
        load(from: completionsURL) ?? []
    }

    func saveCompletions(_ completions: [HabitCompletion]) {
        save(completions, to: completionsURL)
    }

    private var quickTasksURL: URL {
        appSupportURL.appendingPathComponent("quicktasks.json")
    }

    func loadQuickTasks() -> [QuickTask] {
        load(from: quickTasksURL) ?? []
    }

    func saveQuickTasks(_ tasks: [QuickTask]) {
        save(tasks, to: quickTasksURL)
    }

    private var projectsURL: URL {
        appSupportURL.appendingPathComponent("projects.json")
    }

    func loadProjects() -> [Project] {
        load(from: projectsURL) ?? []
    }

    func saveProjects(_ projects: [Project]) {
        save(projects, to: projectsURL)
    }

    private func load<T: Decodable>(from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    private func save<T: Encodable>(_ value: T, to url: URL) {
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
