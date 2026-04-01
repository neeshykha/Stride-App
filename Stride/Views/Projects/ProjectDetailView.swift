import SwiftUI

struct ProjectDetailView: View {
    let project: Project
    @Environment(HabitStore.self) private var store

    @State private var newTaskName = ""
    @State private var newTaskDate: Date? = Date()
    @State private var isAddingTask = false
    @State private var showDatePicker = false
    @State private var editingTaskId: UUID? = nil
    @State private var editingTaskName = ""
    @State private var changingDateTaskId: UUID? = nil
    @State private var notePromptTask: QuickTask? = nil
    @State private var isEditingProject = false
    @State private var editName = ""
    @State private var editColor = ""
    @State private var isSelectMode = false
    @State private var selectedTaskIds: Set<UUID> = []
    @State private var newTaskRecurring = false
    @State private var newTaskRecurrenceInterval = 1
    @State private var newTaskRecurrenceUnit: RecurrenceUnit = .month
    @State private var recurrenceEditTask: QuickTask? = nil
    @State private var editRecurrenceInterval = 1
    @State private var editRecurrenceUnit: RecurrenceUnit = .month
    @FocusState private var isFieldFocused: Bool
    @FocusState private var isEditFieldFocused: Bool

    private var unassignedProjectTasks: [QuickTask] {
        store.tasksForProject(project)
            .filter { $0.date == nil && !$0.isCompleted }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private var tasksByDate: [(date: Date, tasks: [QuickTask])] {
        let allTasks = store.tasksForProject(project).filter { $0.date != nil }
        let grouped = Dictionary(grouping: allTasks) { $0.date! }
        return grouped.keys.sorted().map { date in
            (date: date, tasks: grouped[date]!
                .sorted { ($0.isCompleted ? 1 : 0, $0.createdAt) < ($1.isCompleted ? 1 : 0, $1.createdAt) })
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Project header
                HStack(spacing: 12) {
                    Circle()
                        .fill(project.color)
                        .frame(width: 14, height: 14)

                    Text(project.name)
                        .font(.largeTitle.bold())

                    Spacer()

                    let progress = store.projectProgress(project)
                    if progress.total > 0 {
                        Text("\(progress.completed)/\(progress.total)")
                            .font(.title3.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        editName = project.name
                        editColor = project.colorName
                        isEditingProject = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isSelectMode.toggle()
                            if !isSelectMode { selectedTaskIds.removeAll() }
                        }
                    } label: {
                        Image(systemName: isSelectMode ? "checkmark.circle.fill" : "checkmark.circle")
                            .font(.body)
                            .foregroundStyle(isSelectMode ? project.color : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Select tasks")

                    Button {
                        newTaskDate = Date()
                        isAddingTask = true
                        isFieldFocused = true
                    } label: {
                        Label("Add Task", systemImage: "plus")
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)

                // Bulk action bar
                if isSelectMode && !selectedTaskIds.isEmpty {
                    HStack(spacing: 12) {
                        Text("\(selectedTaskIds.count) selected")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Button {
                            store.clearDates(for: selectedTaskIds)
                            selectedTaskIds.removeAll()
                        } label: {
                            Label("Clear Dates", systemImage: "calendar.badge.minus")
                                .font(.subheadline.bold())
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)

                        Button {
                            selectedTaskIds.removeAll()
                            isSelectMode = false
                        } label: {
                            Text("Cancel")
                                .font(.subheadline)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)
                }

                // Inline add task form
                if isAddingTask {
                    addTaskForm
                        .padding(.horizontal)
                }

                // Tasks grouped by date
                let grouped = tasksByDate
                let unassigned = unassignedProjectTasks
                if grouped.isEmpty && unassigned.isEmpty && !isAddingTask {
                    emptyState
                } else {
                    // Unassigned section at top
                    if !unassigned.isEmpty {
                        unassignedSection(tasks: unassigned)
                    }

                    ForEach(grouped, id: \.date) { group in
                        dateSection(date: group.date, tasks: group.tasks)
                    }

                    // Progress bar
                    let progress = store.projectProgress(project)
                    if progress.total > 0 {
                        HStack {
                            Spacer()
                            VStack(spacing: 4) {
                                Text("\(progress.completed) of \(progress.total) complete")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                ProgressView(value: Double(progress.completed), total: Double(progress.total))
                                    .tint(progress.completed == progress.total ? .green : project.color)
                                    .frame(width: 200)
                            }
                            Spacer()
                        }
                        .padding(.top, 8)
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
        .sheet(item: $recurrenceEditTask) { task in
            VStack(spacing: 12) {
                Text("Set Recurrence")
                    .font(.headline)

                HStack(spacing: 8) {
                    Text("Every")
                        .font(.subheadline)
                    Picker("", selection: $editRecurrenceInterval) {
                        ForEach(1...30, id: \.self) { n in
                            Text("\(n)").tag(n)
                        }
                    }
                    .frame(width: 60)
                    Picker("", selection: $editRecurrenceUnit) {
                        ForEach(RecurrenceUnit.allCases, id: \.self) { unit in
                            Text(editRecurrenceInterval == 1 ? unit.label : unit.pluralLabel).tag(unit)
                        }
                    }
                    .frame(width: 90)
                }

                HStack {
                    Button("Cancel") {
                        recurrenceEditTask = nil
                    }
                    Spacer()
                    Button("Save") {
                        store.setRecurrence(task, interval: editRecurrenceInterval, unit: editRecurrenceUnit)
                        recurrenceEditTask = nil
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .frame(width: 260)
        }
        .sheet(isPresented: $isEditingProject) {
            VStack(spacing: 12) {
                Text("Edit Project")
                    .font(.headline)

                TextField("Project name", text: $editName)
                    .textFieldStyle(.roundedBorder)

                HStack(spacing: 8) {
                    ForEach(Project.availableColors, id: \.name) { item in
                        Circle()
                            .fill(item.color)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .strokeBorder(Color.primary, lineWidth: editColor == item.name ? 2.5 : 0)
                            )
                            .contentShape(Circle())
                            .onTapGesture { editColor = item.name }
                    }
                }

                HStack {
                    Button("Cancel") {
                        isEditingProject = false
                    }

                    Spacer()

                    Button("Save") {
                        let trimmed = editName.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        store.updateProject(project, name: trimmed, colorName: editColor)
                        isEditingProject = false
                    }
                    .disabled(editName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .frame(width: 280)
        }
    }

    // MARK: - Unassigned Section

    private func unassignedSection(tasks: [QuickTask]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "tray")
                    .foregroundStyle(.orange)
                    .font(.headline)
                Text("Unassigned")
                    .font(.headline)
                    .foregroundStyle(.orange)
                Spacer()
                Text("\(tasks.count)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            VStack(spacing: 0) {
                ForEach(tasks) { task in
                    if editingTaskId == task.id {
                        HStack(spacing: 12) {
                            Circle()
                                .strokeBorder(project.color.opacity(0.3), lineWidth: 1.5)
                                .frame(width: 24, height: 24)
                            TextField("Task name", text: $editingTaskName)
                                .textFieldStyle(.plain)
                                .font(.body)
                                .focused($isEditFieldFocused)
                                .onSubmit { commitEdit(for: task) }
                            Button { commitEdit(for: task) } label: {
                                Image(systemName: "checkmark")
                                    .font(.caption.bold())
                                    .foregroundStyle(project.color)
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
                        HStack(spacing: 12) {
                            Button {
                                if task.requiresNote && !task.isCompleted {
                                    notePromptTask = task
                                } else {
                                    store.toggleQuickTask(task)
                                }
                            } label: {
                                ZStack {
                                    Circle()
                                        .strokeBorder(project.color, lineWidth: 1.5)
                                        .frame(width: 24, height: 24)
                                    if task.isCompleted {
                                        Circle()
                                            .fill(project.color.opacity(0.5))
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
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            Spacer()

                            if task.requiresNote && !task.isCompleted {
                                Image(systemName: "pencil.and.list.clipboard")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.orange)
                            }

                            if task.isRecurring {
                                recurrenceBadge(for: task)
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
                            if task.isRecurring {
                                Button("Remove Recurrence") {
                                    store.removeRecurrence(task)
                                }
                            } else {
                                Button("Make Recurring") {
                                    editRecurrenceInterval = 1
                                    editRecurrenceUnit = .month
                                    recurrenceEditTask = task
                                }
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

    // MARK: - Date Section

    private func dateSection(date: Date, tasks: [QuickTask]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Date header
            HStack(spacing: 8) {
                Text(dateSectionLabel(for: date))
                    .font(.headline)
                    .foregroundStyle(project.color)
                Spacer()
                let done = tasks.filter(\.isCompleted).count
                Text("\(done)/\(tasks.count)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            // Task rows
            VStack(spacing: 0) {
                ForEach(tasks) { task in
                    if editingTaskId == task.id {
                        // Inline edit mode
                        HStack(spacing: 12) {
                            Circle()
                                .strokeBorder(project.color.opacity(0.3), lineWidth: 1.5)
                                .frame(width: 24, height: 24)

                            TextField("Task name", text: $editingTaskName)
                                .textFieldStyle(.plain)
                                .font(.body)
                                .focused($isEditFieldFocused)
                                .onSubmit { commitEdit(for: task) }

                            Button { commitEdit(for: task) } label: {
                                Image(systemName: "checkmark")
                                    .font(.caption.bold())
                                    .foregroundStyle(project.color)
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
                        projectTaskRow(task: task)
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

    // MARK: - Task Row

    private func projectTaskRow(task: QuickTask) -> some View {
        Button(action: {
            if isSelectMode {
                if selectedTaskIds.contains(task.id) {
                    selectedTaskIds.remove(task.id)
                } else {
                    selectedTaskIds.insert(task.id)
                }
                return
            }
            if task.requiresNote && !task.isCompleted {
                notePromptTask = task
            } else {
                store.toggleQuickTask(task)
            }
        }) {
            HStack(spacing: 12) {
                if isSelectMode {
                    Image(systemName: selectedTaskIds.contains(task.id) ? "checkmark.square.fill" : "square")
                        .font(.body)
                        .foregroundStyle(selectedTaskIds.contains(task.id) ? project.color : .secondary)
                }
                ZStack {
                    Circle()
                        .strokeBorder(project.color, lineWidth: 1.5)
                        .frame(width: 24, height: 24)

                    if task.isCompleted {
                        Circle()
                            .fill(project.color.opacity(0.5))
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
                    recurrenceBadge(for: task)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contextMenu {
            Button("Edit Task") {
                editingTaskName = task.name
                editingTaskId = task.id
                isEditFieldFocused = true
            }

            Button(task.requiresNote ? "Remove Note Requirement" : "Require Note") {
                store.toggleRequiresNote(task)
            }

            if task.isRecurring {
                Button("Remove Recurrence") {
                    store.removeRecurrence(task)
                }
            } else {
                Button("Make Recurring") {
                    editRecurrenceInterval = 1
                    editRecurrenceUnit = .month
                    recurrenceEditTask = task
                }
            }

            Menu("Move to Date") {
                Button("Today") {
                    store.changeQuickTaskDate(task, to: Date())
                }
                Button("Tomorrow") {
                    store.changeQuickTaskDate(task, to: Calendar.current.date(byAdding: .day, value: 1, to: Date())!)
                }
                Button("In 2 Days") {
                    store.changeQuickTaskDate(task, to: Calendar.current.date(byAdding: .day, value: 2, to: Date())!)
                }
                Button("In 1 Week") {
                    store.changeQuickTaskDate(task, to: Calendar.current.date(byAdding: .day, value: 7, to: Date())!)
                }
                if task.date != nil {
                    Divider()
                    Button("Remove Date") {
                        store.clearQuickTaskDate(task)
                    }
                }
            }

            Divider()
            Button("Delete Task", role: .destructive) {
                store.deleteQuickTask(task)
            }
        }
    }

    private func recurrenceBadge(for task: QuickTask) -> some View {
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

    // MARK: - Add Task Form

    private var addTaskForm: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                Circle()
                    .strokeBorder(project.color.opacity(0.3), lineWidth: 2)
                    .frame(width: 24, height: 24)

                TextField("What do you need to do?", text: $newTaskName)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .focused($isFieldFocused)
                    .onSubmit { submitTask() }

                // No Date chip
                Button {
                    if newTaskDate == nil {
                        newTaskDate = Date()
                    } else {
                        newTaskDate = nil
                        showDatePicker = false
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "calendar.badge.minus")
                            .font(.system(size: 10))
                        Text("No Date")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(newTaskDate == nil ? Color.orange : Color.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(newTaskDate == nil ? Color.orange.opacity(0.12) : Color.secondary.opacity(0.08))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                // Date chip
                if let date = newTaskDate {
                    Button {
                        showDatePicker.toggle()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "calendar")
                                .font(.system(size: 10))
                            Text(dateLabelText(for: date))
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(Calendar.current.isDateInToday(date) ? Color.secondary : project.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.08))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                // Repeat chip
                Button {
                    newTaskRecurring.toggle()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "repeat")
                            .font(.system(size: 10))
                        if newTaskRecurring {
                            Text(newTaskRecurrenceInterval == 1 ? newTaskRecurrenceUnit.label : "\(newTaskRecurrenceInterval) \(newTaskRecurrenceUnit.pluralLabel)")
                                .font(.system(size: 10))
                        } else {
                            Text("Repeat")
                                .font(.system(size: 10))
                        }
                    }
                    .foregroundStyle(newTaskRecurring ? Color.purple : Color.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(newTaskRecurring ? Color.purple.opacity(0.12) : Color.secondary.opacity(0.08))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                if !newTaskName.isEmpty {
                    Button { submitTask() } label: {
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
                    newTaskRecurring = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            if showDatePicker, let bindingDate = Binding<Date>(
                get: { newTaskDate ?? Date() },
                set: { newTaskDate = $0 }
            ) as Binding<Date>? {
                DatePicker(
                    "Date",
                    selection: bindingDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .frame(maxWidth: 280)
                .padding(.leading, 36)
            }

            if newTaskRecurring {
                HStack(spacing: 8) {
                    Text("Every")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Picker("", selection: $newTaskRecurrenceInterval) {
                        ForEach(1...30, id: \.self) { n in
                            Text("\(n)").tag(n)
                        }
                    }
                    .frame(width: 60)
                    Picker("", selection: $newTaskRecurrenceUnit) {
                        ForEach(RecurrenceUnit.allCases, id: \.self) { unit in
                            Text(newTaskRecurrenceInterval == 1 ? unit.label : unit.pluralLabel).tag(unit)
                        }
                    }
                    .frame(width: 90)
                }
                .padding(.leading, 36)
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Helpers

    private func dateSectionLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }

    private func dateLabelText(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private func submitTask() {
        let trimmed = newTaskName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        store.addQuickTask(
            name: trimmed,
            toProject: project,
            on: newTaskDate,
            recurrenceInterval: newTaskRecurring ? newTaskRecurrenceInterval : nil,
            recurrenceUnit: newTaskRecurring ? newTaskRecurrenceUnit : nil
        )
        newTaskName = ""
        newTaskDate = Date()
        newTaskRecurring = false
        isAddingTask = false
        showDatePicker = false
        isFieldFocused = false
    }

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
            Image(systemName: "folder")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No tasks yet")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Add a task to get started")
                .font(.callout)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }
}
