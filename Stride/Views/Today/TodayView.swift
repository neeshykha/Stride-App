import SwiftUI

/// Identifies an item that needs a completion note before toggling.
enum NotePromptItem: Identifiable {
    case quickTask(QuickTask)

    var id: String {
        switch self {
        case .quickTask(let t): return "task-\(t.id)"
        }
    }

    var itemName: String {
        switch self {
        case .quickTask(let t): return t.name
        }
    }
}

struct TodayView: View {
    @Environment(HabitStore.self) private var store
    @Environment(\.workspace) private var workspace
    @State private var confettiTrigger = 0
    @State private var dayOffset: Int = 0
    @State private var notePromptItem: NotePromptItem? = nil

    private var selectedDate: Date {
        Calendar.current.date(byAdding: .day, value: dayOffset, to: Calendar.current.startOfDay(for: Date()))!
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Date header with navigation
                    HStack(spacing: 12) {
                        Button {
                            dayOffset -= 1
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(selectedDate, format: .dateTime.weekday(.wide))
                                .font(.title3)
                                .foregroundStyle(.secondary)
                            Text(selectedDate, format: .dateTime.month(.wide).day())
                                .font(.largeTitle.bold())
                        }

                        Button {
                            dayOffset += 1
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)

                        if dayOffset != 0 {
                            Button {
                                dayOffset = 0
                            } label: {
                                Text("Today")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.accentColor)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }

                        Spacer()
                    }
                    .padding(.horizontal)

                    // Tasks content
                    tasksContent
                }
                .padding(.vertical)
            }

            ConfettiOverlay(trigger: confettiTrigger)
        }
        .sheet(item: $notePromptItem) { item in
            CompletionNoteSheet(
                itemName: item.itemName,
                onSave: { note in
                    handleNoteSave(item: item, note: note)
                    notePromptItem = nil
                },
                onCancel: {
                    notePromptItem = nil
                }
            )
        }
    }

    // MARK: - Tasks Content

    private var tasksContent: some View {
        let dayTasks = store.quickTasksForDate(selectedDate, workspace: workspace)
        let projectTasks = store.projectTasksForDate(selectedDate, workspace: workspace)

        return Group {
            if dayTasks.isEmpty && projectTasks.isEmpty {
                emptyState
            } else {
                VStack(alignment: .leading, spacing: 24) {
                    // Quick tasks section
                    QuickTaskSection(
                        tasks: dayTasks,
                        defaultDate: selectedDate,
                        onToggle: { task in
                            if task.requiresNote && !task.isCompleted {
                                notePromptItem = .quickTask(task)
                            } else {
                                store.toggleQuickTask(task)
                            }
                        },
                        onDelete: { task in
                            store.deleteQuickTask(task)
                        },
                        onAdd: { name, date in
                            store.addQuickTask(name: name, on: date, workspace: workspace)
                        },
                        onRename: { task, newName in
                            store.renameQuickTask(task, to: newName)
                        },
                        onToggleRequiresNote: { task in
                            store.toggleRequiresNote(task)
                        },
                        onRemoveDate: { task in
                            store.clearQuickTaskDate(task)
                        }
                    )

                    // Project tasks assigned to this date
                    if !projectTasks.isEmpty {
                        projectTasksSection(tasks: projectTasks)
                    }

                    // Progress summary
                    let totalTasks = dayTasks.count + projectTasks.count
                    let completedTasks = dayTasks.filter(\.isCompleted).count + projectTasks.filter(\.isCompleted).count
                    if totalTasks > 0 {
                        HStack {
                            Spacer()
                            VStack(spacing: 4) {
                                Text("\(completedTasks) of \(totalTasks) tasks complete")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                ProgressView(value: Double(completedTasks), total: Double(totalTasks))
                                    .tint(completedTasks == totalTasks ? .green : .accentColor)
                                    .frame(width: 200)
                            }
                            Spacer()
                        }
                        .padding(.top, 8)
                    }
                }
            }
        }
    }

    // MARK: - Note Save Handler

    private func handleNoteSave(item: NotePromptItem, note: String) {
        switch item {
        case .quickTask(let task):
            store.toggleQuickTaskWithNote(task, note: note)
        }
    }

    // MARK: - Project Tasks for Date

    private func projectTasksSection(tasks: [QuickTask]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "folder")
                    .foregroundStyle(.secondary)
                    .font(.title3)
                Text("Project Tasks")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                let done = tasks.filter(\.isCompleted).count
                Text("\(done)/\(tasks.count)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            VStack(spacing: 0) {
                ForEach(tasks) { task in
                    let projectColor = task.projectId.flatMap { store.project(for: $0)?.color } ?? Color.secondary

                    Button(action: {
                        if task.requiresNote && !task.isCompleted {
                            notePromptItem = .quickTask(task)
                        } else {
                            store.toggleQuickTask(task)
                        }
                    }) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .strokeBorder(projectColor, lineWidth: 1.5)
                                    .frame(width: 24, height: 24)
                                if task.isCompleted {
                                    Circle()
                                        .fill(projectColor.opacity(0.5))
                                        .frame(width: 24, height: 24)
                                    Image(systemName: "checkmark")
                                        .font(.caption.bold())
                                        .foregroundStyle(.white)
                                }
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(task.name)
                                    .font(.body)
                                    .strikethrough(task.isCompleted, color: .secondary)
                                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                                    .lineLimit(1)

                                // Show completion note if present
                                if let note = task.completionNote, task.isCompleted {
                                    Text(note)
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                        .italic()
                                        .lineLimit(1)
                                }
                            }

                            Spacer()

                            // Note required badge
                            if task.requiresNote && !task.isCompleted {
                                Image(systemName: "pencil.and.list.clipboard")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.orange)
                            }

                            // Recurrence badge
                            if task.isRecurring {
                                HStack(spacing: 3) {
                                    Image(systemName: "repeat")
                                        .font(.system(size: 8))
                                    if let interval = task.recurrenceInterval, let unit = task.recurrenceUnit {
                                        Text(interval == 1 ? unit.label : "\(interval) \(unit.pluralLabel)")
                                            .font(.system(size: 9))
                                    }
                                }
                                .foregroundStyle(.purple)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple.opacity(0.1))
                                .clipShape(Capsule())
                            }

                            // Project badge
                            if let projectId = task.projectId,
                               let project = store.project(for: projectId) {
                                HStack(spacing: 4) {
                                    Circle().fill(project.color).frame(width: 6, height: 6)
                                    Text(project.name)
                                        .font(.system(size: 9))
                                }
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(project.color.opacity(0.1))
                                .clipShape(Capsule())
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .contextMenu {
                        Button(task.requiresNote ? "Remove Note Requirement" : "Require Note") {
                            store.toggleRequiresNote(task)
                        }
                        if task.date != nil {
                            Button("Remove Date") {
                                store.clearQuickTaskDate(task)
                            }
                        }
                        Divider()
                        Button("Delete Task", role: .destructive) {
                            store.deleteQuickTask(task)
                        }
                    }

                    if task.id != tasks.last?.id {
                        Divider()
                            .padding(.leading, 52)
                    }
                }
            }
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checklist")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No tasks for today")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Add quick tasks or assign project tasks to this date")
                .font(.callout)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}
