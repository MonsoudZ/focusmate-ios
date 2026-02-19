import Foundation
import SwiftUI

@Observable
@MainActor
final class TemplateCreationViewModel {
  private let listService: ListService
  private let taskService: TaskService

  var isCreating = false
  var creatingTemplateId: String?
  var createdList: ListDTO?
  var error: FocusmateError?
  var failedTaskCount = 0

  init(listService: ListService, taskService: TaskService) {
    self.listService = listService
    self.taskService = taskService
  }

  /// Creates a list from a template, then sequentially creates each task.
  ///
  /// Sequential task creation is intentional: the backend assigns `position` by insertion order.
  /// Parallel requests arrive nondeterministically and would scramble the template's intended
  /// task ordering. For 5-6 tasks at ~200ms each, total time is ~1 second — acceptable for
  /// the perceived "instant" feel with an inline spinner.
  func createFromTemplate(_ template: ListTemplate) async -> ListDTO? {
    self.isCreating = true
    self.creatingTemplateId = template.id
    self.failedTaskCount = 0
    self.error = nil

    Logger.info("TemplateCreation: Starting '\(template.id)' with \(template.tasks.count) tasks", category: .api)

    do {
      let list = try await listService.createList(
        name: template.name,
        description: template.description,
        color: template.color,
        listType: template.listType.rawValue
      )
      self.createdList = list

      Logger.info(
        "TemplateCreation: List created id=\(list.id), creating \(template.tasks.count) tasks",
        category: .api
      )

      // Default due date: start of today (midnight) — shows as "anytime" in time grouping.
      // The backend requires due_at for task creation; omitting it causes a 422 validation error.
      let defaultDueDate = Calendar.current.startOfDay(for: Date())

      // Create tasks sequentially to preserve position ordering
      for (index, templateTask) in template.tasks.enumerated() {
        do {
          let task = try await taskService.createTask(
            listId: list.id,
            title: templateTask.title,
            note: nil,
            dueAt: defaultDueDate,
            isRecurring: templateTask.isRecurring,
            recurrencePattern: templateTask.recurrencePattern,
            recurrenceInterval: templateTask.recurrenceInterval,
            recurrenceDays: templateTask.recurrenceDays
          )
          Logger.debug(
            "TemplateCreation: Task \(index + 1)/\(template.tasks.count) created id=\(task.id) '\(templateTask.title)'",
            category: .api
          )
        } catch {
          self.failedTaskCount += 1
          Logger.error(
            "TemplateCreation: Task \(index + 1)/\(template.tasks.count) FAILED '\(templateTask.title)'",
            error: error,
            category: .api
          )
        }
      }

      if self.failedTaskCount > 0 {
        Logger.warning(
          "TemplateCreation: Completed with \(self.failedTaskCount)/\(template.tasks.count) task failures",
          category: .api
        )
        self.error = .custom(
          "\(self.failedTaskCount) of \(template.tasks.count) tasks couldn't be created",
          "The list was created but some tasks failed. You can add them manually."
        )
      } else {
        Logger.info("TemplateCreation: All \(template.tasks.count) tasks created successfully", category: .api)
      }

      HapticManager.success()
      self.isCreating = false
      self.creatingTemplateId = nil
      return list

    } catch {
      self.error = ErrorMapper.map(error)
      HapticManager.error()
      self.isCreating = false
      self.creatingTemplateId = nil
      Logger.error(
        "TemplateCreation: Failed to create list from template '\(template.id)'",
        error: error,
        category: .api
      )
      return nil
    }
  }
}
