import SwiftUI

struct ProjectGroupView: View {
    let project: Project
    let tasks: [QuickTask]
    let onToggleTask: (QuickTask) -> Void
    let onDeleteTask: (QuickTask) -> Void
    let onAddTask: (String) -> Void
    let onDeleteProject: () -> Void

    @State private var isExpanded: Bool = true
    @State private var isAddingTask: Bool = false
    @State private var newTaskName: String = ""
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Project header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 12)

                    Circle()
                        .fill(project.color)
                        .frame(width: 8, height: 8)

                    Text(project.name)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)

                    Spacer()

                    let progress = projectProgress
                    Text("\(progress.completed)/\(progress.total)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)

                    Button {
                        isAddingTask = true
                        isFieldFocused = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .contextMenu {
                Button("Delete Project", role: .destructive) { onDeleteProject() }
            }

            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(tasks) { task in
                        Button(action: { onToggleTask(task) }) {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .strokeBorder(project.color.opacity(0.6), lineWidth: 1.5)
                                        .frame(width: 22, height: 22)

                                    if task.isCompleted {
                                        Circle()
                                            .fill(project.color.opacity(0.5))
                                            .frame(width: 22, height: 22)

                                        Image(systemName: "checkmark")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }

                                Text(task.name)
                                    .font(.subheadline)
                                    .strikethrough(task.isCompleted, color: .secondary)
                                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                                    .lineLimit(1)

                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.leading, 20)
                        .padding(.vertical, 7)
                        .contextMenu {
                            Button("Delete Task", role: .destructive) { onDeleteTask(task) }
                        }

                        if task.id != tasks.last?.id || isAddingTask {
                            Divider()
                                .padding(.leading, 68)
                        }
                    }

                    if isAddingTask {
                        HStack(spacing: 12) {
                            Circle()
                                .strokeBorder(project.color.opacity(0.3), lineWidth: 1.5)
                                .frame(width: 22, height: 22)

                            TextField("Add task...", text: $newTaskName)
                                .textFieldStyle(.plain)
                                .font(.subheadline)
                                .focused($isFieldFocused)
                                .onSubmit { submitTask() }

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
                                newTaskName = ""
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16)
                        .padding(.leading, 20)
                        .padding(.vertical, 7)
                    }
                }
            }
        }
    }

    private var projectProgress: (completed: Int, total: Int) {
        let done = tasks.filter(\.isCompleted).count
        return (done, tasks.count)
    }

    private func submitTask() {
        let trimmed = newTaskName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        onAddTask(trimmed)
        newTaskName = ""
    }
}
