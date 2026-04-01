import SwiftUI

struct UnassignedView: View {
    @Environment(HabitStore.self) private var store
    @Environment(\.workspace) private var workspace

    @State private var editingTaskId: UUID? = nil
    @State private var editingTaskName = ""
    @State private var notePromptTask: QuickTask? = nil
    @State private var collapsedProjects: Set<UUID> = []
    @FocusState private var isEditFieldFocused: Bool

    private var unassignedTasks: [QuickTask] {
        store.unassignedTasks(workspace: workspace)
    }

    private var standaloneTasks: [QuickTask] {
        unassignedTasks.filter { $0.projectId == nil }
    }

    private var projectGroups: [(project: Project, tasks: [QuickTask])] {
        let withProject = unassignedTasks.filter { $0.projectId != nil }
        let grouped = Dictionary(grouping: withProject) { $0.projectId! }
        return grouped.keys.compactMap { projectId -> (Project, [QuickTask])? in
            guard let project = store.project(for: projectId) else { return nil }
            return (project, grouped[projectId]!.sorted { $0.createdAt < $1.createdAt })
        }
        .sorted { $0.0.name.localizedCaseInsensitiveCompare($1.0.name) == .orderedAscending }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Unassigned")
                            .font(.largeTitle.bold())
                    }
                    Spacer()
                    let count = unassignedTasks.count
                    if count > 0 {
                        Text("\(count) task\(count == 1 ? "" : "s")")
                            .font(.title3.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)

                if unassignedTasks.isEmpty {
                    emptyState
                } else {
                    // Standalone tasks (no project)
                    if !standaloneTasks.isEmpty {
                        taskSection(
                            title: "Standalone Tasks",
                            icon: "bolt",
                            color: .secondary,
                            tasks: standaloneTasks
                        )
                    }

                    // Per-project sections
                    ForEach(projectGroups, id: \.project.id) { group in
                        projectSection(project: group.project, tasks: group.tasks)
                    }
                }
            }
            .padding(.vertical)
        }
        .sheet(item: $notePromptTask) { task in
            CompletionNoteSheet(
                itemName: task.name,
                onSave: { note in
                    store.toggleQuickTaskWithNote(task, note: note)
                    notePromptTask = nil
                },
                onCancel: {
                    notePromptTask = nil
                }
            )
        }
    }

    // MARK: - Standalone Tasks Section

    private func taskSection(title: String, icon: String, color: Color, tasks: [QuickTask]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.title3)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(tasks.count)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            VStack(spacing: 0) {
                ForEach(tasks) { task in
                    if editingTaskId == task.id {
                        inlineEditRow(task: task, accentColor: color)
                    } else {
                        unassignedTaskRow(task: task, accentColor: color)
                    }

                    if task.id != tasks.last?.id {
                        Divider().padding(.leading, 52)
                    }
                }
            }
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal)
        }
    }

    // MARK: - Project Section

    private func projectSection(project: Project, tasks: [QuickTask]) -> some View {
        let isCollapsed = collapsedProjects.contains(project.id)

        return VStack(alignment: .leading, spacing: 8) {
            // Project header (tap to collapse)
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isCollapsed {
                        collapsedProjects.remove(project.id)
                    } else {
                        collapsedProjects.insert(project.id)
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 12)
                    Circle()
                        .fill(project.color)
                        .frame(width: 10, height: 10)
                    Text(project.name)
                        .font(.headline)
                        .foregroundStyle(project.color)
                    Spacer()
                    Text("\(tasks.count)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal)

            if !isCollapsed {
                VStack(spacing: 0) {
                    ForEach(tasks) { task in
                        if editingTaskId == task.id {
                            inlineEditRow(task: task, accentColor: project.color)
                        } else {
                            unassignedTaskRow(task: task, accentColor: project.color)
                        }

                        if task.id != tasks.last?.id {
                            Divider().padding(.leading, 52)
                        }
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Task Row

    private func unassignedTaskRow(task: QuickTask, accentColor: Color) -> some View {
        HStack(spacing: 12) {
            // Completion toggle
            Button {
                if task.requiresNote && !task.isCompleted {
                    notePromptTask = task
                } else {
                    store.toggleQuickTask(task)
                }
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(accentColor, lineWidth: 1.5)
                        .frame(width: 24, height: 24)
                    if task.isCompleted {
                        Circle()
                            .fill(accentColor.opacity(0.5))
                            .frame(width: 24, height: 24)
                        Image(systemName: "checkmark")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(.plain)

            Text(task.name)
                .font(.body)
                .strikethrough(task.isCompleted, color: .secondary)
                .foregroundStyle(task.isCompleted ? .secondary : .primary)
                .lineLimit(1)

            Spacer()

            // Note required badge
            if task.requiresNote && !task.isCompleted {
                Image(systemName: "pencil.and.list.clipboard")
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
            }

            // Quick-assign buttons
            HStack(spacing: 4) {
                quickAssignButton("Today", color: .orange) {
                    store.changeQuickTaskDate(task, to: Date())
                }
                quickAssignButton("Tmrw", color: .orange) {
                    store.changeQuickTaskDate(task, to: Date().adding(days: 1))
                }
                quickAssignButton("+1W", color: .orange) {
                    store.changeQuickTaskDate(task, to: Date().adding(days: 7))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Edit Task") {
                editingTaskName = task.name
                editingTaskId = task.id
                isEditFieldFocused = true
            }

            Menu("Assign Date") {
                Button("Today") {
                    store.changeQuickTaskDate(task, to: Date())
                }
                Button("Tomorrow") {
                    store.changeQuickTaskDate(task, to: Date().adding(days: 1))
                }
                Button("In 2 Days") {
                    store.changeQuickTaskDate(task, to: Date().adding(days: 2))
                }
                Button("In 1 Week") {
                    store.changeQuickTaskDate(task, to: Date().adding(days: 7))
                }
            }

            Divider()
            Button("Delete Task", role: .destructive) {
                store.deleteQuickTask(task)
            }
        }
    }

    // MARK: - Quick Assign Button

    private func quickAssignButton(_ label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(color)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(color.opacity(0.12))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Inline Edit Row

    private func inlineEditRow(task: QuickTask, accentColor: Color) -> some View {
        HStack(spacing: 12) {
            Circle()
                .strokeBorder(accentColor.opacity(0.3), lineWidth: 1.5)
                .frame(width: 24, height: 24)

            TextField("Task name", text: $editingTaskName)
                .textFieldStyle(.plain)
                .font(.body)
                .focused($isEditFieldFocused)
                .onSubmit { commitEdit(for: task) }

            Button { commitEdit(for: task) } label: {
                Image(systemName: "checkmark")
                    .font(.caption.bold())
                    .foregroundStyle(accentColor)
            }
            .buttonStyle(.plain)

            Button {
                editingTaskId = nil
                editingTaskName = ""
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Helpers

    private func commitEdit(for task: QuickTask) {
        let trimmed = editingTaskName.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty && trimmed != task.name {
            store.renameQuickTask(task, to: trimmed)
        }
        editingTaskId = nil
        editingTaskName = ""
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No unassigned tasks")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Tasks without a date will appear here")
                .font(.callout)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}
