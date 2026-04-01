import SwiftUI

enum SidebarItem: Identifiable, Hashable {
    case today
    case unassigned
    case completed
    case project(UUID)

    var id: String {
        switch self {
        case .today:            return "today"
        case .unassigned:       return "unassigned"
        case .completed:        return "completed"
        case .project(let id):  return "project-\(id.uuidString)"
        }
    }

    var label: String {
        switch self {
        case .today:       return "Today"
        case .unassigned:  return "Unassigned"
        case .completed:   return "Completed"
        case .project:     return ""
        }
    }

    var icon: String {
        switch self {
        case .today:       return "house"
        case .unassigned:  return "tray"
        case .completed:   return "checkmark.circle"
        case .project:     return "folder"
        }
    }

    static var staticItems: [SidebarItem] {
        [.today, .unassigned]
    }
}

struct SidebarView: View {
    @Binding var selection: SidebarItem?
    @Binding var workspace: Workspace
    @Environment(HabitStore.self) private var store

    @State private var showingNewProject = false
    @State private var newProjectName = ""
    @State private var newProjectColor = "blue"

    // Project editing
    @State private var editingProject: Project? = nil
    @State private var editProjectName = ""
    @State private var editProjectColor = ""
    @State private var showCompletedProjects = true

    var body: some View {
        VStack(spacing: 0) {
            // Workspace toggle
            HStack(spacing: 8) {
                workspacePicker
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)

            List(selection: $selection) {
                // Static navigation items
                Section {
                    ForEach(SidebarItem.staticItems) { item in
                        if item == .unassigned {
                            let count = store.unassignedTaskCount(workspace: workspace)
                            Label {
                                HStack {
                                    Text(item.label)
                                    Spacer()
                                    if count > 0 {
                                        Text("\(count)")
                                            .font(.caption.monospacedDigit())
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.orange)
                                            .clipShape(Capsule())
                                    }
                                }
                            } icon: {
                                Image(systemName: item.icon)
                            }
                            .tag(item)
                        } else {
                            Label(item.label, systemImage: item.icon)
                                .tag(item)
                        }
                    }
                }

                // Projects section
                Section {
                    ForEach(store.activeProjectsFor(workspace: workspace)) { project in
                        Label {
                            Text(project.name)
                        } icon: {
                            Circle()
                                .fill(project.color)
                                .frame(width: 10, height: 10)
                        }
                        .tag(SidebarItem.project(project.id))
                        .contextMenu {
                            Button("Edit Project") {
                                editProjectName = project.name
                                editProjectColor = project.colorName
                                editingProject = project
                            }
                            Button("Archive Project") {
                                if selection == .project(project.id) {
                                    selection = .today
                                }
                                store.archiveProject(project)
                            }
                            Divider()
                            Button("Delete Project", role: .destructive) {
                                if selection == .project(project.id) {
                                    selection = .today
                                }
                                store.deleteProject(project)
                            }
                        }
                    }
                    .onMove { from, to in
                        var orderedIds = store.activeProjectsFor(workspace: workspace).map(\.id)
                        orderedIds.move(fromOffsets: from, toOffset: to)
                        store.reorderProjects(orderedIds: orderedIds)
                    }
                } header: {
                    HStack {
                        Text("Projects")
                        Spacer()
                        Button {
                            showingNewProject = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Completed projects nav item
                if !store.completedProjectsFor(workspace: workspace).isEmpty {
                    Section {
                        Label {
                            HStack {
                                Text("Completed")
                                Spacer()
                                Text("\(store.completedProjectsFor(workspace: workspace).count)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.green.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        } icon: {
                            Image(systemName: "checkmark.circle")
                                .foregroundStyle(.green)
                        }
                        .tag(SidebarItem.completed)
                    }
                }
            }
            .listStyle(.sidebar)
            .popover(isPresented: $showingNewProject) {
                VStack(spacing: 12) {
                    Text("New Project")
                        .font(.headline)

                    TextField("Project name", text: $newProjectName)
                        .textFieldStyle(.roundedBorder)

                    HStack(spacing: 8) {
                        ForEach(Project.availableColors, id: \.name) { item in
                            Circle()
                                .fill(item.color)
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.primary, lineWidth: newProjectColor == item.name ? 2.5 : 0)
                                )
                                .contentShape(Circle())
                                .onTapGesture { newProjectColor = item.name }
                        }
                    }

                    HStack {
                        Button("Cancel") {
                            showingNewProject = false
                            newProjectName = ""
                            newProjectColor = "blue"
                        }

                        Spacer()

                        Button("Create") {
                            let trimmed = newProjectName.trimmingCharacters(in: .whitespaces)
                            guard !trimmed.isEmpty else { return }
                            store.addProject(name: trimmed, colorName: newProjectColor, workspace: workspace)
                            newProjectName = ""
                            newProjectColor = "blue"
                            showingNewProject = false
                        }
                        .disabled(newProjectName.trimmingCharacters(in: .whitespaces).isEmpty)
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
                .frame(width: 260)
            }
            .sheet(item: $editingProject) { project in
                VStack(spacing: 12) {
                    Text("Edit Project")
                        .font(.headline)

                    TextField("Project name", text: $editProjectName)
                        .textFieldStyle(.roundedBorder)

                    HStack(spacing: 8) {
                        ForEach(Project.availableColors, id: \.name) { item in
                            Circle()
                                .fill(item.color)
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.primary, lineWidth: editProjectColor == item.name ? 2.5 : 0)
                                )
                                .contentShape(Circle())
                                .onTapGesture { editProjectColor = item.name }
                        }
                    }

                    HStack {
                        Button("Cancel") {
                            editingProject = nil
                        }

                        Spacer()

                        Button("Save") {
                            let trimmed = editProjectName.trimmingCharacters(in: .whitespaces)
                            guard !trimmed.isEmpty else { return }
                            store.updateProject(project, name: trimmed, colorName: editProjectColor)
                            editingProject = nil
                        }
                        .disabled(editProjectName.trimmingCharacters(in: .whitespaces).isEmpty)
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
                .frame(width: 280)
            }
        }
    }

    // MARK: - Workspace Picker

    private var workspacePicker: some View {
        HStack(spacing: 0) {
            ForEach(Workspace.allCases) { ws in
                HStack(spacing: 5) {
                    Image(systemName: ws.icon)
                        .font(.system(size: 10))
                    Text(ws.label)
                        .font(.system(size: 11, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(
                    workspace == ws
                        ? Color.accentColor.opacity(0.15)
                        : Color.clear
                )
                .foregroundStyle(
                    workspace == ws
                        ? Color.accentColor
                        : Color.secondary
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        workspace = ws
                        // Also sync store for backward compatibility
                        store.activeWorkspace = ws
                        // Reset to today when switching workspace to avoid stale project selection
                        if case .project = selection {
                            selection = .today
                        }
                    }
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
