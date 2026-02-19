import Foundation

@MainActor
@Observable
final class QuickAddViewModel {
  private let listService: ListService
  private let taskService: TaskService

  var title = ""
  var selectedList: ListDTO?
  var lists: [ListDTO] = []
  var isLoading = false
  var isLoadingLists = true
  var error: FocusmateError?
  var hasSpecificTime = false
  var dueTime = Date.nextWholeHour()

  var onTaskCreated: (() async -> Void)?

  var canSubmit: Bool {
    !self.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && self.selectedList != nil
      && !self.isLoading
  }

  init(listService: ListService, taskService: TaskService) {
    self.listService = listService
    self.taskService = taskService
  }

  func loadLists() async {
    self.isLoadingLists = true
    defer { isLoadingLists = false }

    do {
      self.lists = try await self.listService.fetchLists()
      self.selectedList = self.lists.first
    } catch {
      Logger.error("Failed to load lists", error: error, category: .api)
      self.error = ErrorHandler.shared.handle(error, context: "Loading lists")
    }
  }

  func createTask() async -> Bool {
    guard let list = selectedList else { return false }

    let trimmedTitle = self.title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedTitle.isEmpty else { return false }

    self.isLoading = true
    defer { isLoading = false }

    do {
      let dueDate: Date
      if self.hasSpecificTime {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: self.dueTime)
        let minute = calendar.component(.minute, from: self.dueTime)
        dueDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
      } else {
        dueDate = Calendar.current.date(bySettingHour: 23, minute: 59, second: 0, of: Date()) ?? Date()
      }

      _ = try await self.taskService.createTask(
        listId: list.id,
        title: trimmedTitle,
        note: nil,
        dueAt: dueDate
      )

      HapticManager.success()
      await self.onTaskCreated?()
      return true
    } catch {
      self.error = ErrorHandler.shared.handle(error, context: "Creating task")
      HapticManager.error()
      return false
    }
  }
}
