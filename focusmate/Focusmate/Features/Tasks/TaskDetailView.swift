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
    listService: ListService,
    listId: Int
  ) {
    _vm = State(initialValue: TaskDetailViewModel(
      task: task,
      listName: listName,
      listId: listId,
      taskService: taskService,
      tagService: tagService,
      subtaskManager: subtaskManager,
      listService: listService,
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
            task: self.vm.task,
            isOverdue: self.vm.isOverdue,
            canEdit: self.vm.canEdit,
            onComplete: self.handleComplete,
            onToggleStar: self.vm.toggleStar,
            onToggleHidden: self.vm.toggleHidden,
            onReschedule: self.presentReschedule,
            onCopyLink: self.vm.copyTaskLink,
            onNudge: self.vm.nudgeTask,
            canHide: self.vm.canHide,
            canNudge: self.vm.canNudge,
            isNudgeOnCooldown: self.vm.isNudgeOnCooldown
          )

          // Info Card (progress + creator)
          if self.vm.hasSubtasks || self.vm.isSharedTask {
            TaskDetailInfoCard(
              hasSubtasks: self.vm.hasSubtasks,
              isSharedTask: self.vm.isSharedTask,
              subtaskProgress: self.vm.subtaskProgress,
              subtaskProgressText: self.vm.subtaskProgressText,
              creator: self.vm.task.creator
            )
          }

          // Visibility Card (who can see this task)
          if !self.vm.listMembers.isEmpty {
            TaskDetailVisibilityCard(members: self.vm.listMembers, listName: self.vm.listName)
          }

          // Details Card
          TaskDetailDetailsCard(
            task: self.vm.task,
            listName: self.vm.listName,
            isOverdue: self.vm.isOverdue
          )

          // Subtasks Card
          if self.vm.hasSubtasks || (self.vm.canEdit && !self.vm.task.isCompleted) {
            TaskDetailSubtasksCard(
              subtasks: self.vm.subtasks,
              hasSubtasks: self.vm.hasSubtasks,
              canEdit: self.vm.canEdit && !self.vm.task.isCompleted,
              subtaskProgressText: self.vm.subtaskProgressText,
              isExpanded: self.$vm.isSubtasksExpanded,
              onAddSubtask: { self.showingAddSubtask = true },
              onToggleComplete: self.vm.toggleSubtaskComplete,
              onDelete: self.vm.deleteSubtask,
              onEdit: { self.editingSubtask = $0 }
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
          if self.vm.hasRescheduleHistory {
            TaskDetailRescheduleHistoryCard(
              rescheduleEvents: self.vm.rescheduleEvents,
              rescheduleCount: self.vm.rescheduleCount,
              isExpanded: self.$vm.isRescheduleHistoryExpanded
            )
          }

          // Actions
          TaskDetailActionsSection(
            task: self.vm.task,
            canEdit: self.vm.canEdit,
            onComplete: self.handleComplete,
            onDelete: { self.vm.showingDeleteConfirmation = true }
          )
        }
        .padding(DS.Spacing.md)
      }
      .surfaceBackground()
      .navigationTitle("Task Details")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          if self.vm.canEdit, !self.vm.task.isCompleted {
            Button("Edit") {
              self.presentEditTask()
            }
          }
        }

        ToolbarItem(placement: .cancellationAction) {
          Button {
            self.dismiss()
          } label: {
            Image(systemName: DS.Icon.close)
          }
        }
      }
      .alert("Delete Task", isPresented: self.$vm.showingDeleteConfirmation) {
        Button("Cancel", role: .cancel) {}
        Button("Delete", role: .destructive) {
          Task {
            await self.vm.onDelete()
            self.dismiss()
          }
        }
      } message: {
        Text("Are you sure you want to delete this task?")
      }
      .sheet(isPresented: self.$showingAddSubtask) {
        AddSubtaskSheet(parentTask: self.vm.task) { title in
          await self.vm.createSubtask(title: title)
        }
      }
      .sheet(item: self.$editingSubtask) { subtask in
        EditSubtaskSheet(subtask: subtask) { newTitle in
          await self.vm.updateSubtask(subtask, title: newTitle)
        }
      }
      .overlay(alignment: .top) {
        TaskDetailToastOverlay(
          showNudgeSent: self.vm.showNudgeSent,
          showCopied: self.vm.showCopied
        )
        .animateIfAllowed(.spring(duration: 0.3), value: self.vm.showNudgeSent || self.vm.showCopied)
      }
      .floatingErrorBanner(self.$vm.error)
      .task {
        await self.vm.loadListInfo()
      }
    }
  }

  // MARK: - Sheet Presentation

  private func presentEditTask() {
    self.router.sheetCallbacks.onTaskSaved = {
      Task {
        await self.vm.onUpdate()
        self.dismiss()
      }
    }
    self.router.present(.editTask(self.vm.task, listId: self.vm.listId))
  }

  private func presentOverdueReason() {
    self.router.sheetCallbacks.onOverdueReasonSubmitted = { _ in
      Task {
        await self.vm.onComplete()
        self.router.dismissSheet()
        self.dismiss()
      }
    }
    self.router.present(.overdueReason(self.vm.task))
  }

  private func presentReschedule() {
    self.router.sheetCallbacks.onRescheduleSubmitted = { newDate, reason in
      await self.vm.rescheduleTask(newDate: newDate, reason: reason)
      self.router.dismissSheet()
      self.dismiss()
    }
    self.router.present(.rescheduleTask(self.vm.task))
  }

  // MARK: - Actions

  private func handleComplete() {
    if self.vm.task.isCompleted {
      Task {
        await self.vm.onComplete()
        self.dismiss()
      }
    } else if self.vm.requiresCompletionReason {
      // Require reason if task is overdue OR if it was overdue and user edited the due date
      // This prevents gaming the escalation by pushing the due date forward
      self.presentOverdueReason()
    } else {
      Task {
        await self.vm.onComplete()
        self.dismiss()
      }
    }
  }
}
