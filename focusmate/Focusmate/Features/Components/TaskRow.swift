import SwiftUI

struct TaskRow: View {
    let task: TaskDTO
    let escalationService: EscalationService
    let onComplete: () async -> Void
    let onStar: () async -> Void
    let onTap: () -> Void
    let onNudge: () async -> Void
    let onHide: () async -> Void
    let onSubtaskEdit: (SubtaskDTO) -> Void
    let onAddSubtask: () -> Void
    let showStar: Bool
    let showNudge: Bool
    let showHide: Bool

    @EnvironmentObject var state: AppState
    @Environment(\.router) private var router
    @State private var isNudging = false
    @State private var isExpanded = false
    @State private var isCompleting = false
    @State private var completionError: FocusmateError?

    private var isOverdue: Bool { task.isActuallyOverdue }
    private var isTrackedForEscalation: Bool { escalationService.isTaskTracked(task.id) }
    private var canEdit: Bool { task.can_edit ?? true }
    private var canDelete: Bool { task.can_delete ?? true }
    private var canNudge: Bool { showNudge && !task.isCompleted }

    init(
        task: TaskDTO,
        escalationService: EscalationService = .shared,
        onComplete: @escaping () async -> Void,
        onStar: @escaping () async -> Void = {},
        onTap: @escaping () -> Void = {},
        onNudge: @escaping () async -> Void = {},
        onHide: @escaping () async -> Void = {},
        onSubtaskEdit: @escaping (SubtaskDTO) -> Void = { _ in },
        onAddSubtask: @escaping () -> Void = {},
        showStar: Bool = true,
        showNudge: Bool = false,
        showHide: Bool = false
    ) {
        self.task = task
        self.escalationService = escalationService
        self.onComplete = onComplete
        self.onStar = onStar
        self.onTap = onTap
        self.onNudge = onNudge
        self.onHide = onHide
        self.onSubtaskEdit = onSubtaskEdit
        self.onAddSubtask = onAddSubtask
        self.showStar = showStar
        self.showNudge = showNudge
        self.showHide = showHide
    }

    var body: some View {
        HStack(spacing: 0) {
            // List color indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(task.taskColor)
                .frame(width: 4)
                .padding(.vertical, DS.Spacing.sm)

            VStack(spacing: 0) {
                mainTaskRow

                // Subtasks section
                if task.hasSubtasks && isExpanded {
                    subtasksList
                } else if !task.hasSubtasks && canEdit {
                    Divider()
                        .padding(.horizontal, DS.Spacing.md)
                    addSubtaskButton
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .stroke(isOverdue ? DS.Colors.error.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .opacity(task.isCompleted ? 0.6 : 1.0)
        .onAppear {
            if isOverdue && !task.isCompleted {
                Task { @MainActor in
                    escalationService.taskBecameOverdue(task)
                }
            }
        }
        .floatingErrorBanner($completionError)
        .if(showHide) { view in
            view.contextMenu {
                Button {
                    Task { await onHide() }
                } label: {
                    Label(
                        task.isHidden ? "Show to Members" : "Hide from Members",
                        systemImage: task.isHidden ? "eye" : "eye.slash"
                    )
                }
            }
        }
    }

    // MARK: - Main Task Row

    private var mainTaskRow: some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            TaskRowCheckbox(
                task: task,
                canEdit: canEdit,
                isCompleting: isCompleting,
                isOverdue: isOverdue,
                onTap: handleCompleteTap
            )
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                TaskRowTitle(task: task, canEdit: canEdit, isOverdue: isOverdue)

                TaskRowMetadata(
                    task: task,
                    isOverdue: isOverdue,
                    isExpanded: isExpanded,
                    onExpandToggle: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                        HapticManager.selection()
                    }
                )
            }
            .contentShape(Rectangle())
            .onTapGesture {
                HapticManager.selection()
                onTap()
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Task: \(task.title)")
            .accessibilityHint("Double tap to view details")
            .accessibilityAddTraits(.isButton)

            Spacer(minLength: DS.Spacing.sm)

            TaskRowActions(
                task: task,
                showStar: showStar,
                canEdit: canEdit,
                canNudge: canNudge,
                isNudging: isNudging,
                onStar: onStar,
                onNudge: {
                    Task {
                        isNudging = true
                        await onNudge()
                        isNudging = false
                    }
                }
            )
        }
        .padding(DS.Spacing.md)
    }

    // MARK: - Subtasks List

    private var subtasksList: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.horizontal, DS.Spacing.md)

            VStack(spacing: 0) {
                if let subtasks = task.subtasks {
                    ForEach(subtasks) { subtask in
                        SubtaskRow(
                            subtask: subtask,
                            canEdit: canEdit,
                            onComplete: {
                                do {
                                    _ = try await state.subtaskManager.toggleComplete(subtask: subtask, parentTask: task)
                                } catch {
                                    Logger.error("Failed to toggle subtask: \(error)", category: .api)
                                    HapticManager.error()
                                }
                            },
                            onDelete: {
                                do {
                                    try await state.subtaskManager.delete(subtask: subtask, parentTask: task)
                                } catch {
                                    Logger.error("Failed to delete subtask: \(error)", category: .api)
                                    HapticManager.error()
                                }
                            },
                            onTap: {
                                onSubtaskEdit(subtask)
                            }
                        )

                        if subtask.id != subtasks.last?.id {
                            Divider()
                                .padding(.leading, 52)
                        }
                    }
                }

                if canEdit {
                    Divider()
                        .padding(.leading, 52)
                    addSubtaskButton
                }
            }
            .padding(.leading, 36)
        }
        .background(Color(.tertiarySystemBackground))
    }

    private var addSubtaskButton: some View {
        Button {
            HapticManager.selection()
            onAddSubtask()
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "plus.circle")
                    .font(.system(size: DS.Size.iconMedium))

                Text("Add subtask")
                    .font(DS.Typography.caption)

                Spacer()
            }
            .foregroundStyle(DS.Colors.accent)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func handleCompleteTap() {
        guard canEdit else { return }
        HapticManager.selection()

        if task.isCompleted {
            isCompleting = true
            Task {
                defer { isCompleting = false }
                await onComplete()
            }
        } else if isOverdue || isTrackedForEscalation {
            // Require reason if task is overdue OR if it was overdue and user edited the due date
            // This prevents gaming the escalation by pushing the due date forward
            presentOverdueReasonSheet()
        } else {
            isCompleting = true
            Task {
                await completeTask(reason: nil)
            }
        }
    }

    private func presentOverdueReasonSheet() {
        router.sheetCallbacks.onOverdueReasonSubmitted = { reason in
            Task {
                await completeTask(reason: reason)
                router.dismissSheet()
            }
        }
        router.present(.overdueReason(task))
    }

    private func completeTask(reason: String?) async {
        defer { isCompleting = false }
        do {
            _ = try await state.taskService.completeTask(
                listId: task.list_id,
                taskId: task.id,
                reason: reason
            )

            await MainActor.run {
                escalationService.taskCompleted(task.id)
            }

            HapticManager.success()
            await onComplete()
        } catch {
            Logger.error("Failed to complete task", error: error, category: .api)
            HapticManager.error()
            completionError = ErrorHandler.shared.handle(error, context: "Completing task")
        }
    }
}
