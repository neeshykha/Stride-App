import SwiftUI

// Environment key for per-window workspace
private struct WorkspaceKey: EnvironmentKey {
    static let defaultValue: Workspace = .personal
}

extension EnvironmentValues {
    var workspace: Workspace {
        get { self[WorkspaceKey.self] }
        set { self[WorkspaceKey.self] = newValue }
    }
}

struct ContentView: View {
    @State private var selectedSidebar: SidebarItem? = .today
    @State private var windowWorkspace: Workspace = .personal
    @Environment(HabitStore.self) private var store

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selectedSidebar, workspace: $windowWorkspace)
                .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 250)
        } detail: {
            Group {
                switch selectedSidebar {
                case .today:
                    TodayView()
                case .unassigned:
                    UnassignedView()
                case .completed:
                    CompletedProjectsView(selection: $selectedSidebar)
                case .project(let id):
                    if let project = store.projects.first(where: { $0.id == id }) {
                        ProjectDetailView(project: project)
                    } else {
                        TodayView()
                    }
                case .none:
                    TodayView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .environment(\.workspace, windowWorkspace)
        .navigationTitle(windowWorkspace.label)
    }
}
