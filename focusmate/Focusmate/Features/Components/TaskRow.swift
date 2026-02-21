import SwiftUI

struct TaskRow: View {
  let task: TaskDTO
  let escalationService: EscalationService
  let onComplete: () async -> Void
  let onStar: () async -> Void
  let onTap: () -> Void
  let onNudge: () async -> Void
  let onHide: () async -> Void
  let onDelete: () async -> Void
  let onSubtaskEdit: (SubtaskDTO) -> Void
  let onAddSubtask: () -> Void
  let showStar: Bool
  let showNudge: Bool
  let showHide: Bool
  let showDelete: Bool

  @Environment(AppState.self) var state
  @Environment(\.router) private var router
  @State private var isNudging = false
  @State private var isExpanded = false
  @State private var isCompleting = false
  @State private var completionError: FocusmateError?

  private var isOverdue: Bool {
    self.task.isActuallyOverdue
  }

  private var isTrackedForEscalation: Bool {
    self.escalationService.isTaskTracked(self.task.id)
  }

  private var canEdit: Bool {
    self.task.can_edit ?? true
  }

  private var canDelete: Bool {
    self.task.can_delete ?? true
  }

  private var canNudge: Bool {
    self.showNudge && !self.task.isCompleted && !NudgeCooldownManager.shared.isOnCooldown(taskId: self.task.id)
  }

  init(
    task: TaskDTO,
    escalationService: EscalationService = .shared,
    onComplete: @escaping () async -> Void,
    onStar: @escaping () async -> Void = {},
    onTap: @escaping () -> Void = {},
    onNudge: @escaping () async -> Void = {},
    onHide: @escaping () async -> Void = {},
    onDelete: @escaping () async -> Void = {},
    onSubtaskEdit: @escaping (SubtaskDTO) -> Void = { _ in },
    onAddSubtask: @escaping () -> Void = {},
    showStar: Bool = true,
    showNudge: Bool = false,
    showHide: Bool = false,
    showDelete: Bool = false
  ) {
    self.task = task
    self.escalationService = escalationService
    self.onComplete = onComplete
    self.onStar = onStar
    self.onTap = onTap
    self.onNudge = onNudge
    self.onHide = onHide
    self.onDelete = onDelete
    self.onSubtaskEdit = onSubtaskEdit
    self.onAddSubtask = onAddSubtask
    self.showStar = showStar
    self.showNudge = showNudge
    self.showHide = showHide
    self.showDelete = showDelete
  }

  var body: some View {
    HStack(spacing: 0) {
      // List color indicator
      RoundedRectangle(cornerRadius: 2)
        .fill(self.task.taskColor)
        .frame(width: 4)
        .padding(.vertical, DS.Spacing.sm)

      VStack(spacing: 0) {
        self.mainTaskRow

        // Subtasks section
        if self.task.hasSubtasks, self.isExpanded {
          self.subtasksList
        } else if !self.task.hasSubtasks, self.canEdit, !self.task.isCompleted {
          Divider()
            .padding(.horizontal, DS.Spacing.md)
          self.addSubtaskButton
        }
      }
    }
    .background(Color(.secondarySystemGroupedBackground))
    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
        .stroke(self.isOverdue ? DS.Colors.error.opacity(0.3) : Color.clear, lineWidth: 1)
    )
    .opacity(self.task.isCompleted ? 0.6 : 1.0)
    .onAppear {
      if self.isOverdue, !self.task.isCompleted {
        Task { @MainActor in
          self.escalationService.taskBecameOverdue(self.task)
        }
      }
    }
    .floatingErrorBanner(self.$completionError)
    .if(self.showHide || self.showDelete) { view in
      view.contextMenu {
        if self.showHide {
          Button {
            Task { await self.onHide() }
          } label: {
            Label(
              self.task.isHidden ? "Show to Members" : "Hide from Members",
              systemImage: self.task.isHidden ? "eye" : "eye.slash"
            )
          }
        }

        if self.showDelete {
          Button(role: .destructive) {
            Task { await self.onDelete() }
          } label: {
            Label("Delete", systemImage: DS.Icon.trash)
          }
        }
      }
    }
  }

  // MARK: - Main Task Row

  private var mainTaskRow: some View {
    HStack(alignment: .top, spacing: DS.Spacing.sm) {
      TaskRowCheckbox(
        task: self.task,
        canEdit: self.canEdit,
        isCompleting: self.isCompleting,
        isOverdue: self.isOverdue,
        onTap: self.handleCompleteTap
      )
      .padding(.top, 2)

      VStack(alignment: .leading, spacing: DS.Spacing.xs) {
        TaskRowTitle(task: self.task, canEdit: self.canEdit, isOverdue: self.isOverdue)

        TaskRowMetadata(
          task: self.task,
          isOverdue: self.isOverdue,
          isExpanded: self.isExpanded,
          onExpandToggle: {
            withAnimation(.easeInOut(duration: 0.2)) {
              self.isExpanded.toggle()
            }
            HapticManager.selection()
          }
        )
      }
      .contentShape(Rectangle())
      .onTapGesture {
        HapticManager.selection()
        self.onTap()
      }
      .accessibilityElement(children: .combine)
      .accessibilityLabel("Task: \(self.task.title)")
      .accessibilityHint("Double tap to view details")
      .accessibilityAddTraits(.isButton)

      Spacer(minLength: DS.Spacing.sm)

      TaskRowActions(
        task: self.task,
        showStar: self.showStar,
        canEdit: self.canEdit,
        canNudge: self.canNudge,
        isNudging: self.isNudging,
        onStar: self.onStar,
        onNudge: {
          Task {
            self.isNudging = true
            await self.onNudge()
            self.isNudging = false
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
              canEdit: self.canEdit,
              onComplete: {
                do {
                  _ = try await self.state.subtaskManager.toggleComplete(subtask: subtask, parentTask: self.task)
                } catch {
                  Logger.error("Failed to toggle subtask: \(error)", category: .api)
                  HapticManager.error()
                }
              },
              onDelete: {
                do {
                  try await self.state.subtaskManager.delete(subtask: subtask, parentTask: self.task)
                } catch {
                  Logger.error("Failed to delete subtask: \(error)", category: .api)
                  HapticManager.error()
                }
              },
              onTap: {
                self.onSubtaskEdit(subtask)
              }
            )

            if subtask.id != subtasks.last?.id {
              Divider()
                .padding(.leading, 52)
            }
          }
        }

        if self.canEdit, !self.task.isCompleted {
          Divider()
            .padding(.leading, 52)
          self.addSubtaskButton
        }
      }
      .padding(.leading, 36)
    }
    .background(Color(.tertiarySystemBackground))
  }

  private var addSubtaskButton: some View {
    Button {
      HapticManager.selection()
      self.onAddSubtask()
    } label: {
      HStack(spacing: DS.Spacing.sm) {
        Image(systemName: "plus.circle")
          .scaledFont(size: DS.Size.iconMedium, relativeTo: .title3)

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
    guard self.canEdit else { return }
    HapticManager.selection()

    if self.task.isCompleted {
      self.isCompleting = true
      Task {
        defer { isCompleting = false }
        await self.onComplete()
      }
    } else if self.isOverdue || self.isTrackedForEscalation {
      // Require reason if task is overdue OR if it was overdue and user edited the due date
      // This prevents gaming the escalation by pushing the due date forward
      self.presentOverdueReasonSheet()
    } else {
      self.isCompleting = true
      Task {
        await self.completeTask(reason: nil)
      }
    }
  }

  private func presentOverdueReasonSheet() {
    self.router.sheetCallbacks.onOverdueReasonSubmitted = { reason in
      Task {
        await self.completeTask(reason: reason)
        self.router.dismissSheet()
      }
    }
    self.router.present(.overdueReason(self.task))
  }

  private func completeTask(reason: String?) async {
    defer { isCompleting = false }
    do {
      _ = try await self.state.taskService.completeTask(
        listId: self.task.list_id,
        taskId: self.task.id,
        reason: reason
      )

      await MainActor.run {
        self.escalationService.taskCompleted(self.task.id)
      }

      HapticManager.success()
      await self.onComplete()
    } catch {
      Logger.error("Failed to complete task", error: error, category: .api)
      HapticManager.error()
      self.completionError = ErrorHandler.shared.handle(error, context: "Completing task")
    }
  }
}
