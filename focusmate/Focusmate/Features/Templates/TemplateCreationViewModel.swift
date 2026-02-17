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
    isCreating = true
    creatingTemplateId = template.id
    failedTaskCount = 0
    error = nil

    do {
      let list = try await listService.createList(
        name: template.name,
        description: template.description,
        color: template.color,
        listType: template.listType.rawValue
      )
      createdList = list

      // Create tasks sequentially to preserve position ordering
      for templateTask in template.tasks {
        do {
          _ = try await taskService.createTask(
            listId: list.id,
            title: templateTask.title,
            note: nil,
            dueAt: nil,
            isRecurring: templateTask.isRecurring,
            recurrencePattern: templateTask.recurrencePattern,
            recurrenceInterval: templateTask.recurrenceInterval,
            recurrenceDays: templateTask.recurrenceDays
          )
        } catch {
          failedTaskCount += 1
          Logger.warning(
            "TemplateCreation: Failed to create task '\(templateTask.title)' in list \(list.id): \(error)",
            category: .api
          )
        }
      }

      HapticManager.success()
      isCreating = false
      creatingTemplateId = nil
      return list

    } catch {
      self.error = ErrorMapper.map(error)
      HapticManager.error()
      isCreating = false
      creatingTemplateId = nil
      Logger.error(
        "TemplateCreation: Failed to create list from template '\(template.id)': \(error)",
        category: .api
      )
      return nil
    }
  }
}
