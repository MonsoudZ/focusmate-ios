import Foundation

@MainActor
protocol TaskSideEffectHandling {
  func taskCreated(_ task: TaskDTO, isSubtask: Bool)
  func taskUpdated(_ task: TaskDTO)
  func taskDeleted(taskId: Int)
  func taskCompleted(taskId: Int)
  func taskReopened(_ task: TaskDTO)
}

@MainActor
final class TaskSideEffectHandler: TaskSideEffectHandling {
  private let notificationService: NotificationService
  private let calendarService: CalendarService

  init(
    notificationService: NotificationService,
    calendarService: CalendarService
  ) {
    self.notificationService = notificationService
    self.calendarService = calendarService
  }

  func taskCreated(_ task: TaskDTO, isSubtask: Bool) {
    guard !isSubtask else { return }
    self.notificationService.scheduleTaskNotifications(for: task)
    self.calendarService.addTaskToCalendar(task)
  }

  func taskUpdated(_ task: TaskDTO) {
    self.notificationService.scheduleTaskNotifications(for: task)
    self.calendarService.updateTaskInCalendar(task)
  }

  func taskDeleted(taskId: Int) {
    self.notificationService.cancelTaskNotifications(for: taskId)
    self.calendarService.removeTaskFromCalendar(taskId: taskId)
  }

  func taskCompleted(taskId: Int) {
    self.notificationService.cancelTaskNotifications(for: taskId)
    self.calendarService.removeTaskFromCalendar(taskId: taskId)
  }

  func taskReopened(_ task: TaskDTO) {
    self.notificationService.scheduleTaskNotifications(for: task)
    self.calendarService.addTaskToCalendar(task)
  }
}
