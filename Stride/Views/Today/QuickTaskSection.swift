import SwiftUI

struct QuickTaskSection: View {
    let tasks: [QuickTask]
    let defaultDate: Date
    let onToggle: (QuickTask) -> Void
    let onDelete: (QuickTask) -> Void
    let onAdd: (String, Date) -> Void
    var onRename: ((QuickTask, String) -> Void)? = nil
    var onToggleRequiresNote: ((QuickTask) -> Void)? = nil
    var onRemoveDate: ((QuickTask) -> Void)? = nil
    var compact: Bool = false

    @State private var newTaskName: String = ""
    @State private var newTaskDate: Date = Date()
    @State private var isAddingTask = false
    @State private var showDatePicker = false
    @State private var editingTaskId: UUID? = nil
    @State private var editingTaskName: String = ""
    @FocusState private var isFieldFocused: Bool
    @FocusState private var isEditFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section header
            HStack(spacing: 8) {
                Image(systemName: "bolt")
                    .foregroundStyle(.secondary)
                    .font(compact ? .body : .title3)
                Text("Tasks")
                    .font(compact ? .subheadline.bold() : .headline)
                    .foregroundStyle(.secondary)
                Spacer()

                if !tasks.isEmpty {
                    let done = tasks.filter(\.isCompleted).count
                    Text("\(done)/\(tasks.count)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Button {
                    newTaskDate = defaultDate
                    isAddingTask = true
                    isFieldFocused = true
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)

            VStack(spacing: 0) {
                // Standalone tasks
                ForEach(tasks) { task in
                    if editingTaskId == task.id {
                        // Inline edit mode
                        HStack(spacing: 12) {
                            Circle()
                                .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1.5)
                                .frame(width: 24, height: 24)

                            TextField("Task name", text: $editingTaskName)
                                .textFieldStyle(.plain)
                                .font(.body)
                                .focused($isEditFieldFocused)
                                .onSubmit {
                                    commitEdit(for: task)
                                }

                            Button {
                                commitEdit(for: task)
                            } label: {
                                Image(systemName: "checkmark")
                                    .font(.caption.bold())
                                    .foregroundStyle(Color.accentColor)
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
                    } else {
                        QuickTaskRow(
                            task: task,
                            showDate: task.date.map { !Calendar.current.isDateInToday($0) } ?? false,
                            onToggle: { onToggle(task) },
                            onDelete: { onDelete(task) },
                            onEdit: {
                                editingTaskName = task.name
                                editingTaskId = task.id
                                isEditFieldFocused = true
                            },
                            onToggleRequiresNote: onToggleRequiresNote != nil ? { onToggleRequiresNote?(task) } : nil,
                            onRemoveDate: onRemoveDate != nil ? { onRemoveDate?(task) } : nil
                        )
                    }

                    if task.id != tasks.last?.id || isAddingTask {
                        Divider()
                            .padding(.leading, 52)
                    }
                }

                // Inline add field
                if isAddingTask {
                    VStack(spacing: 6) {
                        HStack(spacing: 12) {
                            Circle()
                                .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 2)
                                .frame(width: 24, height: 24)

                            TextField("What do you need to do?", text: $newTaskName)
                                .textFieldStyle(.plain)
                                .font(.body)
                                .focused($isFieldFocused)
                                .onSubmit {
                                    submitTask()
                                }

                            // Date chip
                            Button {
                                showDatePicker.toggle()
                            } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 10))
                                    Text(dateLabelText)
                                        .font(.system(size: 10))
                                }
                                .foregroundStyle(Calendar.current.isDateInToday(newTaskDate) ? Color.secondary : Color.accentColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.secondary.opacity(0.08))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)

                            if !newTaskName.isEmpty {
                                Button {
                                    submitTask()
                                } label: {
                                    Image(systemName: "return")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }

                            Button {
                                isAddingTask = false
                                showDatePicker = false
                                newTaskName = ""
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }

                        if showDatePicker {
                            DatePicker(
                                "Date",
                                selection: $newTaskDate,
                                in: Date()...,
                                displayedComponents: .date
                            )
                            .datePickerStyle(.graphical)
                            .frame(maxWidth: 280)
                            .padding(.leading, 36)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
            }
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal)
        }
    }

    private var dateLabelText: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(newTaskDate) { return "Today" }
        if calendar.isDateInTomorrow(newTaskDate) { return "Tomorrow" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: newTaskDate)
    }

    private func submitTask() {
        let trimmed = newTaskName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        onAdd(trimmed, newTaskDate)
        newTaskName = ""
    }

    private func commitEdit(for task: QuickTask) {
        let trimmed = editingTaskName.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty && trimmed != task.name {
            onRename?(task, trimmed)
        }
        editingTaskId = nil
        editingTaskName = ""
    }
}

struct QuickTaskRow: View {
    let task: QuickTask
    var showDate: Bool = false
    let onToggle: () -> Void
    let onDelete: () -> Void
    var onEdit: (() -> Void)? = nil
    var onToggleRequiresNote: (() -> Void)? = nil
    var onRemoveDate: (() -> Void)? = nil

    @State private var isHovered = false

    private var dateBadgeText: String? {
        guard showDate, let date = task.date else { return nil }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return nil }
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .strokeBorder(Color.secondary, lineWidth: 1.5)
                        .frame(width: 24, height: 24)

                    if task.isCompleted {
                        Circle()
                            .fill(Color.secondary.opacity(0.5))
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

                if let dateText = dateBadgeText {
                    Text(dateText)
                        .font(.system(size: 9))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(Capsule())
                }

                if !task.isRecurring {
                    Text("one-off")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.08))
                        .clipShape(Capsule())
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isHovered ? Color.primary.opacity(0.04) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onHover { isHovered = $0 }
        .contextMenu {
            if let onEdit {
                Button("Edit Task") { onEdit() }
            }
            if let onToggleRequiresNote {
                Button(task.requiresNote ? "Remove Note Requirement" : "Require Note") {
                    onToggleRequiresNote()
                }
            }
            if let onRemoveDate, task.date != nil {
                Button("Remove Date") {
                    onRemoveDate()
                }
            }
            Button("Delete Task", role: .destructive) { onDelete() }
        }
    }
}
