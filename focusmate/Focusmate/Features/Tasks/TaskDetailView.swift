import SwiftUI

struct TaskDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.router) private var router
    @State private var vm: TaskDetailViewModel
    @State private var showingAddSubtask = false
    @State private var editingSubtask: SubtaskDTO?

    init(
        task: TaskDTO,
        listName: String,
        onComplete: @escaping () async -> Void,
        onDelete: @escaping () async -> Void,
        onUpdate: @escaping () async -> Void,
        taskService: TaskService,
        tagService: TagService,
        subtaskManager: SubtaskManager,
        listId: Int
    ) {
        _vm = State(initialValue: TaskDetailViewModel(
            task: task,
            listName: listName,
            listId: listId,
            taskService: taskService,
            tagService: tagService,
            subtaskManager: subtaskManager,
            onComplete: onComplete,
            onDelete: onDelete,
            onUpdate: onUpdate
        ))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.md) {
                    // Header Card
                    TaskDetailHeaderCard(
                        task: vm.task,
                        isOverdue: vm.isOverdue,
                        canEdit: vm.canEdit,
                        onComplete: handleComplete,
                        onToggleStar: vm.toggleStar,
                        onToggleHidden: vm.toggleHidden,
                        onReschedule: presentReschedule,
                        onCopyLink: vm.copyTaskLink,
                        onNudge: vm.nudgeTask,
                        canHide: vm.canHide,
                        isSharedTask: vm.isSharedTask
                    )

                    // Info Card (progress + creator)
                    if vm.hasSubtasks || vm.isSharedTask {
                        TaskDetailInfoCard(
                            hasSubtasks: vm.hasSubtasks,
                            isSharedTask: vm.isSharedTask,
                            subtaskProgress: vm.subtaskProgress,
                            subtaskProgressText: vm.subtaskProgressText,
                            creator: vm.task.creator
                        )
                    }

                    // Details Card
                    TaskDetailDetailsCard(
                        task: vm.task,
                        listName: vm.listName,
                        isOverdue: vm.isOverdue
                    )

                    // Subtasks Card
                    if vm.hasSubtasks || vm.canEdit {
                        TaskDetailSubtasksCard(
                            subtasks: vm.subtasks,
                            hasSubtasks: vm.hasSubtasks,
                            canEdit: vm.canEdit,
                            subtaskProgressText: vm.subtaskProgressText,
                            isExpanded: $vm.isSubtasksExpanded,
                            onAddSubtask: { showingAddSubtask = true },
                            onToggleComplete: vm.toggleSubtaskComplete,
                            onDelete: vm.deleteSubtask,
                            onEdit: { editingSubtask = $0 }
                        )
                    }

                    // Tags Card
                    if let tags = vm.task.tags, !tags.isEmpty {
                        TaskDetailTagsCard(tags: tags)
                    }

                    // Notes Card
                    if let note = vm.task.note, !note.isEmpty {
                        TaskDetailNotesCard(note: note)
                    }

                    // Missed Reason Card
                    if let missedReason = vm.task.missed_reason, !missedReason.isEmpty {
                        TaskDetailMissedReasonCard(reason: missedReason)
                    }

                    // Reschedule History Card
                    if vm.hasRescheduleHistory {
                        TaskDetailRescheduleHistoryCard(
                            rescheduleEvents: vm.rescheduleEvents,
                            rescheduleCount: vm.rescheduleCount,
                            isExpanded: $vm.isRescheduleHistoryExpanded
                        )
                    }

                    // Actions
                    TaskDetailActionsSection(
                        task: vm.task,
                        canEdit: vm.canEdit,
                        onComplete: handleComplete,
                        onDelete: { vm.showingDeleteConfirmation = true }
                    )
                }
                .padding(DS.Spacing.md)
            }
            .surfaceBackground()
            .navigationTitle("Task Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if vm.canEdit {
                        Button("Edit") {
                            presentEditTask()
                        }
                    }
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: DS.Icon.close)
                    }
                }
            }
            .alert("Delete Task", isPresented: $vm.showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task {
                        await vm.onDelete()
                        dismiss()
                    }
                }
            } message: {
                Text("Are you sure you want to delete this task?")
            }
            .sheet(isPresented: $showingAddSubtask) {
                AddSubtaskSheet(parentTask: vm.task) { title in
                    await vm.createSubtask(title: title)
                }
            }
            .sheet(item: $editingSubtask) { subtask in
                EditSubtaskSheet(subtask: subtask) { newTitle in
                    await vm.updateSubtask(subtask, title: newTitle)
                }
            }
            .overlay(alignment: .top) {
                TaskDetailToastOverlay(
                    showNudgeSent: vm.showNudgeSent,
                    showCopied: vm.showCopied
                )
                .animation(.spring(duration: 0.3), value: vm.showNudgeSent || vm.showCopied)
            }
            .floatingErrorBanner($vm.error)
        }
    }

    // MARK: - Sheet Presentation

    private func presentEditTask() {
        router.sheetCallbacks.onTaskSaved = {
            Task {
                await vm.onUpdate()
                dismiss()
            }
        }
        router.present(.editTask(vm.task, listId: vm.listId))
    }

    private func presentOverdueReason() {
        router.sheetCallbacks.onOverdueReasonSubmitted = { _ in
            Task {
                await vm.onComplete()
                router.dismissSheet()
                dismiss()
            }
        }
        router.present(.overdueReason(vm.task))
    }

    private func presentReschedule() {
        router.sheetCallbacks.onRescheduleSubmitted = { newDate, reason in
            await vm.rescheduleTask(newDate: newDate, reason: reason)
            router.dismissSheet()
            dismiss()
        }
        router.present(.rescheduleTask(vm.task))
    }

    // MARK: - Actions

    private func handleComplete() {
        if vm.task.isCompleted {
            Task {
                await vm.onComplete()
                dismiss()
            }
        } else if vm.requiresCompletionReason {
            // Require reason if task is overdue OR if it was overdue and user edited the due date
            // This prevents gaming the escalation by pushing the due date forward
            presentOverdueReason()
        } else {
            Task {
                await vm.onComplete()
                dismiss()
            }
        }
    }
}
