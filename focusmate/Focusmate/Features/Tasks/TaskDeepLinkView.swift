import SwiftUI

/// View that handles deep link navigation to a specific task.
/// Fetches the task by ID and displays the task detail.
struct TaskDeepLinkView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.router) private var router

    private let taskId: Int
    private let taskService: TaskService
    private let tagService: TagService
    private let subtaskManager: SubtaskManager

    @State private var task: TaskDTO?
    @State private var isLoading = true
    @State private var error: FocusmateError?

    init(taskId: Int, taskService: TaskService, tagService: TagService, subtaskManager: SubtaskManager) {
        self.taskId = taskId
        self.taskService = taskService
        self.tagService = tagService
        self.subtaskManager = subtaskManager
    }

    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if let task {
                TaskDetailView(
                    task: task,
                    listName: task.list_name ?? "",
                    onComplete: { await refreshTask() },
                    onDelete: { dismiss() },
                    onUpdate: { await refreshTask() },
                    taskService: taskService,
                    tagService: tagService,
                    subtaskManager: subtaskManager,
                    listId: task.list_id
                )
            } else {
                errorView
            }
        }
        .task {
            await loadTask()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        NavigationStack {
            VStack(spacing: DS.Spacing.md) {
                ProgressView()
                Text("Loading task...")
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Task Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: DS.Icon.close)
                    }
                }
            }
        }
    }

    // MARK: - Error View

    private var errorView: some View {
        NavigationStack {
            VStack(spacing: DS.Spacing.lg) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)

                Text("Unable to load task")
                    .font(DS.Typography.headline)

                if let error {
                    Text(error.message)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button("Try Again") {
                    Task { await loadTask() }
                }
                .buttonStyle(IntentiaSecondaryButtonStyle())
            }
            .padding(DS.Spacing.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Task Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: DS.Icon.close)
                    }
                }
            }
        }
    }

    // MARK: - Data Loading

    private func loadTask() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            task = try await taskService.fetchTaskById(taskId)
        } catch let fetchError as FocusmateError {
            error = fetchError
            Logger.error("Failed to fetch task for deep link", error: fetchError, category: .api)
        } catch {
            self.error = .custom("UNKNOWN_ERROR", error.localizedDescription)
            Logger.error("Failed to fetch task for deep link", error: error, category: .api)
        }
    }

    private func refreshTask() async {
        do {
            task = try await taskService.fetchTaskById(taskId)
        } catch {
            Logger.error("Failed to refresh task", error: error, category: .api)
        }
    }
}
