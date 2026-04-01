import Foundation
import SwiftUI

@Observable
final class HabitStore {
    var habits: [Habit] = []
    var completions: [HabitCompletion] = []
    var quickTasks: [QuickTask] = []
    var projects: [Project] = []
    var activeWorkspace: Workspace = .personal

    private let storage = StorageService.shared

    init() {
        habits = storage.loadHabits()
        completions = storage.loadCompletions()
        quickTasks = storage.loadQuickTasks()
        projects = storage.loadProjects()
    }

    // MARK: - Computed Properties

    var today: Date { Calendar.current.startOfDay(for: Date()) }
    var todayDayOfWeek: DayOfWeek { DayOfWeek.from(date: today) }

    /// Central scheduling predicate — handles both weekly and interval habits
    func isScheduled(_ habit: Habit, on date: Date, workspace ws: Workspace? = nil) -> Bool {
        guard !habit.isArchived else { return false }
        guard habit.workspace == (ws ?? activeWorkspace) else { return false }
        let normalized = Calendar.current.startOfDay(for: date)

        // Don't show habits before they were created
        let createdDay = Calendar.current.startOfDay(for: habit.createdAt)
        guard normalized >= createdDay else { return false }

        switch habit.scheduleType {
        case .weekly:
            let dayOfWeek = DayOfWeek.from(date: normalized)
            return habit.scheduledDays.contains(dayOfWeek)

        case .interval:
            guard let intervalDays = habit.intervalDays,
                  let startDate = habit.intervalStartDate else { return false }
            let start = Calendar.current.startOfDay(for: startDate)
            guard normalized >= start else { return false }
            let daysBetween = Calendar.current.dateComponents([.day], from: start, to: normalized).day ?? 0
            return daysBetween % intervalDays == 0
        }
    }

    var todaysHabits: [Habit] {
        habitsForDate(today)
    }

    func habitsForDay(_ day: DayOfWeek, workspace ws: Workspace? = nil) -> [Habit] {
        let w = ws ?? activeWorkspace
        return habits
            .filter { !$0.isArchived && $0.workspace == w && $0.scheduleType == .weekly && $0.scheduledDays.contains(day) }
            .sorted { ($0.timeCategory.sortOrder, $0.sortIndex) < ($1.timeCategory.sortOrder, $1.sortIndex) }
    }

    func habitsForDate(_ date: Date, workspace ws: Workspace? = nil) -> [Habit] {
        habits
            .filter { isScheduled($0, on: date, workspace: ws) }
            .sorted { ($0.timeCategory.sortOrder, $0.sortIndex) < ($1.timeCategory.sortOrder, $1.sortIndex) }
    }

    func habitsByCategory(for day: DayOfWeek, workspace ws: Workspace? = nil) -> [(TimeCategory, [Habit])] {
        let dayHabits = habitsForDay(day, workspace: ws)
        return TimeCategory.allCases.compactMap { category in
            let matching = dayHabits.filter { $0.timeCategory == category }
                .sorted { $0.sortIndex < $1.sortIndex }
            return matching.isEmpty ? nil : (category, matching)
        }
    }

    func habitsByCategory(for date: Date, workspace ws: Workspace? = nil) -> [(TimeCategory, [Habit])] {
        let dayHabits = habitsForDate(date, workspace: ws)
        return TimeCategory.allCases.compactMap { category in
            let matching = dayHabits.filter { $0.timeCategory == category }
                .sorted { $0.sortIndex < $1.sortIndex }
            return matching.isEmpty ? nil : (category, matching)
        }
    }

    /// How many tally/subtask marks for this habit on this date
    func tallyCount(for habit: Habit, on date: Date) -> Int {
        let normalized = Calendar.current.startOfDay(for: date)
        return completions.filter { $0.habitId == habit.id && $0.date == normalized }.count
    }

    /// Whether a habit is fully completed on a date
    func isCompleted(_ habit: Habit, on date: Date) -> Bool {
        return tallyCount(for: habit, on: date) >= habit.targetCount
    }

    func completionCount(for date: Date, workspace ws: Workspace? = nil) -> (completed: Int, total: Int) {
        let scheduled = habitsForDate(date, workspace: ws)
        let done = scheduled.filter { isCompleted($0, on: date) }.count
        return (done, scheduled.count)
    }

    // MARK: - Subtask Queries

    func isSubtaskCompleted(_ subtaskId: UUID, for habit: Habit, on date: Date) -> Bool {
        let normalized = Calendar.current.startOfDay(for: date)
        return completions.contains {
            $0.habitId == habit.id && $0.date == normalized && $0.subtaskId == subtaskId
        }
    }

    func completedSubtaskIds(for habit: Habit, on date: Date) -> Set<UUID> {
        guard habit.habitType == .checklist else { return [] }
        let normalized = Calendar.current.startOfDay(for: date)
        return Set(
            completions
                .filter { $0.habitId == habit.id && $0.date == normalized && $0.subtaskId != nil }
                .compactMap { $0.subtaskId }
        )
    }

    // MARK: - Streaks

    func currentStreak(for habit: Habit) -> Int {
        var streak = 0
        var checkDate = Calendar.current.startOfDay(for: Date())
        let calendar = Calendar.current

        for _ in 0..<365 {
            if isScheduled(habit, on: checkDate) {
                if isCompleted(habit, on: checkDate) {
                    streak += 1
                } else {
                    if calendar.isDateInToday(checkDate) {
                        checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
                        continue
                    }
                    break
                }
            }

            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
        }
        return streak
    }

    func longestStreak(for habit: Habit) -> Int {
        let habitCompletions = completions
            .filter { $0.habitId == habit.id }
            .map { $0.date }
            .sorted()

        guard !habitCompletions.isEmpty else { return 0 }

        var longest = 0
        var current = 0
        let calendar = Calendar.current

        var checkDate = habit.createdAt.startOfDay
        let today = calendar.startOfDay(for: Date())

        while checkDate <= today {
            if isScheduled(habit, on: checkDate) {
                if habitCompletions.contains(checkDate) {
                    current += 1
                    longest = max(longest, current)
                } else {
                    current = 0
                }
            }
            checkDate = calendar.date(byAdding: .day, value: 1, to: checkDate)!
        }

        return longest
    }

    func completionRate(for habit: Habit) -> Double {
        let calendar = Calendar.current
        var checkDate = habit.createdAt.startOfDay
        let today = calendar.startOfDay(for: Date())
        var scheduledCount = 0
        var completedCount = 0

        while checkDate <= today {
            if isScheduled(habit, on: checkDate) {
                scheduledCount += 1
                if isCompleted(habit, on: checkDate) {
                    completedCount += 1
                }
            }
            checkDate = calendar.date(byAdding: .day, value: 1, to: checkDate)!
        }

        return scheduledCount > 0 ? Double(completedCount) / Double(scheduledCount) : 0
    }

    // MARK: - Mutations

    /// Toggle for habits. Returns true if now completed.
    func toggleCompletion(for habit: Habit, on date: Date = Date()) -> Bool {
        let normalized = Calendar.current.startOfDay(for: date)

        switch habit.habitType {
        case .tally:
            return incrementTally(for: habit, on: date)

        case .checklist:
            if isCompleted(habit, on: date) {
                // Uncomplete all subtasks
                completions.removeAll { $0.habitId == habit.id && $0.date == normalized }
                storage.saveCompletions(completions)
                return false
            } else {
                // Complete all remaining subtasks
                for subtask in habit.subtasks {
                    if !isSubtaskCompleted(subtask.id, for: habit, on: date) {
                        completions.append(HabitCompletion(habitId: habit.id, date: date, subtaskId: subtask.id))
                    }
                }
                storage.saveCompletions(completions)
                return true
            }

        case .checkbox:
            if let index = completions.firstIndex(where: { $0.habitId == habit.id && $0.date == normalized }) {
                completions.remove(at: index)
                storage.saveCompletions(completions)
                return false
            } else {
                completions.append(HabitCompletion(habitId: habit.id, date: date))
                storage.saveCompletions(completions)
                return true
            }
        }
    }

    /// Toggle a specific subtask. Returns true if the habit is now fully completed.
    func toggleSubtask(_ subtaskId: UUID, for habit: Habit, on date: Date) -> Bool {
        let normalized = Calendar.current.startOfDay(for: date)
        if let index = completions.firstIndex(where: {
            $0.habitId == habit.id && $0.date == normalized && $0.subtaskId == subtaskId
        }) {
            completions.remove(at: index)
            storage.saveCompletions(completions)
        } else {
            completions.append(HabitCompletion(habitId: habit.id, date: date, subtaskId: subtaskId))
            storage.saveCompletions(completions)
        }
        return isCompleted(habit, on: date)
    }

    /// Add one tally mark. Returns true if habit is now fully completed.
    @discardableResult
    func incrementTally(for habit: Habit, on date: Date = Date()) -> Bool {
        let current = tallyCount(for: habit, on: date)
        guard current < habit.targetCount else { return true }
        completions.append(HabitCompletion(habitId: habit.id, date: date))
        storage.saveCompletions(completions)
        return (current + 1) >= habit.targetCount
    }

    /// Remove one tally mark. Returns the new count.
    @discardableResult
    func decrementTally(for habit: Habit, on date: Date = Date()) -> Int {
        let normalized = Calendar.current.startOfDay(for: date)
        if let index = completions.lastIndex(where: { $0.habitId == habit.id && $0.date == normalized }) {
            completions.remove(at: index)
            storage.saveCompletions(completions)
        }
        return tallyCount(for: habit, on: date)
    }

    func addHabit(_ habit: Habit, workspace ws: Workspace? = nil) {
        let w = ws ?? activeWorkspace
        var newHabit = habit
        newHabit.workspace = w
        let maxIndex = habits
            .filter { $0.timeCategory == habit.timeCategory && $0.workspace == w }
            .map(\.sortIndex)
            .max() ?? -1
        newHabit.sortIndex = maxIndex + 1
        habits.append(newHabit)
        storage.saveHabits(habits)
    }

    func updateHabit(_ habit: Habit) {
        if let index = habits.firstIndex(where: { $0.id == habit.id }) {
            habits[index] = habit
            // Clean up orphaned subtask completions
            if habit.habitType == .checklist {
                let validIds = Set(habit.subtasks.map(\.id))
                completions.removeAll {
                    $0.habitId == habit.id && $0.subtaskId != nil && !validIds.contains($0.subtaskId!)
                }
                storage.saveCompletions(completions)
            }
            storage.saveHabits(habits)
        }
    }

    /// Move a habit to a different time category, placing it at the end.
    func moveHabitToCategory(_ habit: Habit, category: TimeCategory, workspace ws: Workspace? = nil) {
        let w = ws ?? activeWorkspace
        guard let index = habits.firstIndex(where: { $0.id == habit.id }) else { return }
        let maxIndex = habits
            .filter { $0.timeCategory == category && $0.workspace == w }
            .map(\.sortIndex)
            .max() ?? -1
        habits[index].timeCategory = category
        habits[index].sortIndex = maxIndex + 1
        storage.saveHabits(habits)
    }

    /// Reorder habits within a category after a drag & drop.
    func reorderHabits(in category: TimeCategory, orderedIds: [UUID]) {
        for (newIndex, id) in orderedIds.enumerated() {
            if let idx = habits.firstIndex(where: { $0.id == id }) {
                habits[idx].sortIndex = newIndex
            }
        }
        storage.saveHabits(habits)
    }

    /// Move a habit to a specific position in a (possibly different) category.
    func moveHabit(_ habit: Habit, toCategory category: TimeCategory, atIndex targetIndex: Int, workspace ws: Workspace? = nil) {
        let w = ws ?? activeWorkspace
        guard let idx = habits.firstIndex(where: { $0.id == habit.id }) else { return }

        // Get ordered habits in the target category (excluding the moved habit)
        var categoryHabits = habits
            .filter { $0.timeCategory == category && $0.workspace == w && $0.id != habit.id }
            .sorted { $0.sortIndex < $1.sortIndex }

        // Insert at the target position
        let clampedIndex = min(targetIndex, categoryHabits.count)
        habits[idx].timeCategory = category
        categoryHabits.insert(habits[idx], at: clampedIndex)

        // Reassign sort indices
        for (i, h) in categoryHabits.enumerated() {
            if let hIdx = habits.firstIndex(where: { $0.id == h.id }) {
                habits[hIdx].sortIndex = i
            }
        }
        storage.saveHabits(habits)
    }

    func deleteHabit(_ habit: Habit) {
        habits.removeAll { $0.id == habit.id }
        completions.removeAll { $0.habitId == habit.id }
        storage.saveHabits(habits)
        storage.saveCompletions(completions)
    }

    // MARK: - Quick Tasks

    func quickTasksForDate(_ date: Date, workspace ws: Workspace? = nil) -> [QuickTask] {
        let w = ws ?? activeWorkspace
        let normalized = Calendar.current.startOfDay(for: date)
        let today = Calendar.current.startOfDay(for: Date())
        return quickTasks
            .filter { task in
                guard let taskDate = task.date else { return false }
                guard task.projectId == nil && task.workspace == w else { return false }
                if taskDate == normalized { return true }
                if normalized == today && !task.isCompleted && taskDate < today { return true }
                return false
            }
            .sorted { ($0.isCompleted ? 1 : 0, ($0.date ?? .distantFuture) > ($1.date ?? .distantFuture) ? 1 : 0, $0.createdAt) < ($1.isCompleted ? 1 : 0, ($1.date ?? .distantFuture) > ($0.date ?? .distantFuture) ? 1 : 0, $1.createdAt) }
    }

    func addQuickTask(name: String, on date: Date? = Date(), workspace ws: Workspace? = nil) {
        let w = ws ?? activeWorkspace
        let task = QuickTask(name: name, date: date, workspace: w)
        quickTasks.append(task)
        storage.saveQuickTasks(quickTasks)
    }

    func toggleQuickTask(_ task: QuickTask) {
        if let index = quickTasks.firstIndex(where: { $0.id == task.id }) {
            let wasCompleted = quickTasks[index].isCompleted
            quickTasks[index].isCompleted.toggle()
            quickTasks[index].completedAt = quickTasks[index].isCompleted ? Date() : nil
            storage.saveQuickTasks(quickTasks)
            // Spawn next recurrence only when completing (not uncompleting)
            if !wasCompleted && quickTasks[index].isCompleted {
                spawnNextRecurrence(from: quickTasks[index])
            }
        }
    }

    func renameQuickTask(_ task: QuickTask, to newName: String) {
        if let index = quickTasks.firstIndex(where: { $0.id == task.id }) {
            quickTasks[index].name = newName
            storage.saveQuickTasks(quickTasks)
        }
    }

    func deleteQuickTask(_ task: QuickTask) {
        quickTasks.removeAll { $0.id == task.id }
        storage.saveQuickTasks(quickTasks)
    }

    // MARK: - Projects

    var activeProjects: [Project] {
        activeProjectsFor(workspace: activeWorkspace)
    }

    var completedProjects: [Project] {
        completedProjectsFor(workspace: activeWorkspace)
    }

    func activeProjectsFor(workspace ws: Workspace) -> [Project] {
        projects
            .filter { !$0.isArchived && $0.workspace == ws }
            .sorted { $0.sortIndex < $1.sortIndex }
            .filter { project in
                let progress = projectProgress(project)
                return progress.total == 0 || progress.completed < progress.total
            }
    }

    func completedProjectsFor(workspace ws: Workspace) -> [Project] {
        projects
            .filter { !$0.isArchived && $0.workspace == ws }
            .sorted { $0.sortIndex < $1.sortIndex }
            .filter { project in
                let progress = projectProgress(project)
                return progress.total > 0 && progress.completed == progress.total
            }
    }

    func tasksForProject(_ project: Project) -> [QuickTask] {
        quickTasks
            .filter { $0.projectId == project.id }
            .sorted { ($0.isCompleted ? 1 : 0, $0.createdAt) < ($1.isCompleted ? 1 : 0, $1.createdAt) }
    }

    func projectProgress(_ project: Project) -> (completed: Int, total: Int) {
        let tasks = quickTasks.filter { $0.projectId == project.id }
        let done = tasks.filter(\.isCompleted).count
        return (done, tasks.count)
    }

    func addProject(name: String, colorName: String = "blue", workspace ws: Workspace? = nil) {
        let w = ws ?? activeWorkspace
        let maxIndex = projects
            .filter { $0.workspace == w }
            .map(\.sortIndex)
            .max() ?? -1
        let project = Project(name: name, colorName: colorName, workspace: w, sortIndex: maxIndex + 1)
        projects.append(project)
        storage.saveProjects(projects)
    }

    func reorderProjects(orderedIds: [UUID]) {
        for (newIndex, id) in orderedIds.enumerated() {
            if let idx = projects.firstIndex(where: { $0.id == id }) {
                projects[idx].sortIndex = newIndex
            }
        }
        storage.saveProjects(projects)
    }

    func updateProject(_ project: Project, name: String, colorName: String) {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index].name = name
            projects[index].colorName = colorName
            storage.saveProjects(projects)
        }
    }

    func archiveProject(_ project: Project) {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index].isArchived = true
            storage.saveProjects(projects)
        }
    }

    func unarchiveProject(_ project: Project) {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index].isArchived = false
            storage.saveProjects(projects)
        }
    }

    func deleteProject(_ project: Project) {
        quickTasks.removeAll { $0.projectId == project.id }
        storage.saveQuickTasks(quickTasks)
        projects.removeAll { $0.id == project.id }
        storage.saveProjects(projects)
    }

    func addQuickTask(name: String, toProject project: Project, on date: Date? = Date(), recurrenceInterval: Int? = nil, recurrenceUnit: RecurrenceUnit? = nil) {
        let isRecurring = recurrenceInterval != nil && recurrenceUnit != nil
        let task = QuickTask(name: name, date: date, projectId: project.id, workspace: project.workspace, isRecurring: isRecurring, recurrenceInterval: recurrenceInterval, recurrenceUnit: recurrenceUnit)
        quickTasks.append(task)
        storage.saveQuickTasks(quickTasks)
    }

    // MARK: - Recurrence

    private func spawnNextRecurrence(from task: QuickTask) {
        guard task.isRecurring,
              let interval = task.recurrenceInterval,
              let unit = task.recurrenceUnit else { return }
        let calendarUnit: Calendar.Component = switch unit {
        case .day: .day
        case .week: .weekOfYear
        case .month: .month
        }
        let nextDate = Calendar.current.date(byAdding: calendarUnit, value: interval, to: Date())!
        let newTask = QuickTask(
            name: task.name,
            date: nextDate,
            projectId: task.projectId,
            workspace: task.workspace,
            requiresNote: task.requiresNote,
            isRecurring: true,
            recurrenceInterval: interval,
            recurrenceUnit: unit
        )
        quickTasks.append(newTask)
        storage.saveQuickTasks(quickTasks)
    }

    func setRecurrence(_ task: QuickTask, interval: Int, unit: RecurrenceUnit) {
        if let index = quickTasks.firstIndex(where: { $0.id == task.id }) {
            quickTasks[index].isRecurring = true
            quickTasks[index].recurrenceInterval = interval
            quickTasks[index].recurrenceUnit = unit
            storage.saveQuickTasks(quickTasks)
        }
    }

    func removeRecurrence(_ task: QuickTask) {
        if let index = quickTasks.firstIndex(where: { $0.id == task.id }) {
            quickTasks[index].isRecurring = false
            quickTasks[index].recurrenceInterval = nil
            quickTasks[index].recurrenceUnit = nil
            storage.saveQuickTasks(quickTasks)
        }
    }

    func changeQuickTaskDate(_ task: QuickTask, to newDate: Date) {
        if let index = quickTasks.firstIndex(where: { $0.id == task.id }) {
            quickTasks[index].date = Calendar.current.startOfDay(for: newDate)
            storage.saveQuickTasks(quickTasks)
        }
    }

    func clearQuickTaskDate(_ task: QuickTask) {
        if let index = quickTasks.firstIndex(where: { $0.id == task.id }) {
            quickTasks[index].date = nil
            storage.saveQuickTasks(quickTasks)
        }
    }

    func clearDates(for ids: Set<UUID>) {
        for id in ids {
            if let index = quickTasks.firstIndex(where: { $0.id == id }) {
                quickTasks[index].date = nil
            }
        }
        storage.saveQuickTasks(quickTasks)
    }

    func unassignedTasks(workspace ws: Workspace? = nil) -> [QuickTask] {
        let w = ws ?? activeWorkspace
        return quickTasks
            .filter { $0.date == nil && !$0.isCompleted && $0.workspace == w }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func unassignedTaskCount(workspace ws: Workspace? = nil) -> Int {
        let w = ws ?? activeWorkspace
        return quickTasks.count { $0.date == nil && !$0.isCompleted && $0.workspace == w }
    }

    func projectTasksForDate(_ date: Date, workspace ws: Workspace? = nil) -> [QuickTask] {
        let w = ws ?? activeWorkspace
        let normalized = Calendar.current.startOfDay(for: date)
        let today = Calendar.current.startOfDay(for: Date())
        return quickTasks
            .filter { task in
                guard let taskDate = task.date else { return false }
                guard task.projectId != nil && task.workspace == w else { return false }
                if taskDate == normalized { return true }
                if normalized == today && !task.isCompleted && taskDate < today { return true }
                return false
            }
            .sorted { ($0.isCompleted ? 1 : 0, ($0.date ?? .distantFuture) > ($1.date ?? .distantFuture) ? 1 : 0, $0.createdAt) < ($1.isCompleted ? 1 : 0, ($1.date ?? .distantFuture) > ($0.date ?? .distantFuture) ? 1 : 0, $1.createdAt) }
    }

    func project(for id: UUID) -> Project? {
        projects.first { $0.id == id }
    }

    // MARK: - Note-Aware Completions

    /// Toggle completion with a note attached. Returns true if now completed.
    func toggleCompletionWithNote(for habit: Habit, on date: Date, note: String) -> Bool {
        let normalized = Calendar.current.startOfDay(for: date)

        switch habit.habitType {
        case .tally:
            let current = tallyCount(for: habit, on: date)
            guard current < habit.targetCount else { return true }
            completions.append(HabitCompletion(habitId: habit.id, date: date, note: note))
            storage.saveCompletions(completions)
            return (current + 1) >= habit.targetCount

        case .checklist:
            // Complete all remaining subtasks with the note on the first one
            var first = true
            for subtask in habit.subtasks {
                if !isSubtaskCompleted(subtask.id, for: habit, on: date) {
                    completions.append(HabitCompletion(habitId: habit.id, date: date, subtaskId: subtask.id, note: first ? note : nil))
                    first = false
                }
            }
            storage.saveCompletions(completions)
            return true

        case .checkbox:
            completions.append(HabitCompletion(habitId: habit.id, date: date, note: note))
            storage.saveCompletions(completions)
            return true
        }
    }

    /// Toggle a specific subtask with a note. Returns true if the habit is now fully completed.
    func toggleSubtaskWithNote(_ subtaskId: UUID, for habit: Habit, on date: Date, note: String) -> Bool {
        let normalized = Calendar.current.startOfDay(for: date)
        if let index = completions.firstIndex(where: {
            $0.habitId == habit.id && $0.date == normalized && $0.subtaskId == subtaskId
        }) {
            completions.remove(at: index)
            storage.saveCompletions(completions)
        } else {
            completions.append(HabitCompletion(habitId: habit.id, date: date, subtaskId: subtaskId, note: note))
            storage.saveCompletions(completions)
        }
        return isCompleted(habit, on: date)
    }

    /// Toggle quick task with a note.
    func toggleQuickTaskWithNote(_ task: QuickTask, note: String) {
        if let index = quickTasks.firstIndex(where: { $0.id == task.id }) {
            let wasCompleted = quickTasks[index].isCompleted
            quickTasks[index].isCompleted.toggle()
            quickTasks[index].completedAt = quickTasks[index].isCompleted ? Date() : nil
            quickTasks[index].completionNote = quickTasks[index].isCompleted ? note : nil
            storage.saveQuickTasks(quickTasks)
            if !wasCompleted && quickTasks[index].isCompleted {
                spawnNextRecurrence(from: quickTasks[index])
            }
        }
    }

    /// Toggle requiresNote on a quick task.
    func toggleRequiresNote(_ task: QuickTask) {
        if let index = quickTasks.firstIndex(where: { $0.id == task.id }) {
            quickTasks[index].requiresNote.toggle()
            storage.saveQuickTasks(quickTasks)
        }
    }

    // MARK: - Note Queries

    /// Get completion notes for a specific habit, sorted by most recent first.
    func completionNotes(for habit: Habit, limit: Int = 20) -> [(date: Date, note: String)] {
        completions
            .filter { $0.habitId == habit.id && $0.note != nil && !$0.note!.isEmpty }
            .sorted { $0.completedAt > $1.completedAt }
            .prefix(limit)
            .map { ($0.date, $0.note!) }
    }

    /// Get all recent completion notes across habits and tasks for the active workspace.
    func recentNotes(limit: Int = 20, workspace ws: Workspace? = nil) -> [(itemName: String, note: String, date: Date)] {
        let w = ws ?? activeWorkspace
        var results: [(String, String, Date)] = []

        // Habit completion notes
        for completion in completions {
            guard let note = completion.note, !note.isEmpty else { continue }
            if let habit = habits.first(where: { $0.id == completion.habitId && $0.workspace == w }) {
                results.append((habit.name, note, completion.completedAt))
            }
        }

        // Quick task completion notes
        for task in quickTasks {
            guard let note = task.completionNote, !note.isEmpty,
                  task.workspace == w else { continue }
            results.append((task.name, note, task.completedAt ?? task.createdAt))
        }

        return results
            .sorted { $0.2 > $1.2 }
            .prefix(limit)
            .map { $0 }
    }
}
