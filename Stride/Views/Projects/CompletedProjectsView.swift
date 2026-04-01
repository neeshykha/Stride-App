import SwiftUI

struct CompletedProjectsView: View {
    @Binding var selection: SidebarItem?
    @Environment(HabitStore.self) private var store
    @Environment(\.workspace) private var workspace

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.green)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Completed Projects")
                            .font(.largeTitle.bold())
                        Text("\(store.completedProjectsFor(workspace: workspace).count) project\(store.completedProjectsFor(workspace: workspace).count == 1 ? "" : "s") completed")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(.horizontal)

                if store.completedProjectsFor(workspace: workspace).isEmpty {
                    emptyState
                } else {
                    // Project cards
                    LazyVStack(spacing: 12) {
                        ForEach(store.completedProjectsFor(workspace: workspace)) { project in
                            completedProjectCard(project)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }

    private func completedProjectCard(_ project: Project) -> some View {
        let progress = store.projectProgress(project)

        return Button {
            selection = .project(project.id)
        } label: {
            HStack(spacing: 16) {
                // Color indicator
                RoundedRectangle(cornerRadius: 4)
                    .fill(project.color)
                    .frame(width: 6, height: 48)

                VStack(alignment: .leading, spacing: 4) {
                    Text(project.name)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                        Text("\(progress.total) task\(progress.total == 1 ? "" : "s") completed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Reopen button
                Button {
                    let tasks = store.tasksForProject(project)
                    if let lastCompleted = tasks.last(where: { $0.isCompleted }) {
                        store.toggleQuickTask(lastCompleted)
                    }
                } label: {
                    Text("Reopen")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "party.popper")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No completed projects yet")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Complete all tasks in a project to see it here")
                .font(.callout)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }
}
