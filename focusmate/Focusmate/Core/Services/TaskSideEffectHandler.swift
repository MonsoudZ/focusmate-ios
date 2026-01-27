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
        notificationService.scheduleTaskNotifications(for: task)
        calendarService.addTaskToCalendar(task)
    }

    func taskUpdated(_ task: TaskDTO) {
        notificationService.scheduleTaskNotifications(for: task)
        calendarService.updateTaskInCalendar(task)
    }

    func taskDeleted(taskId: Int) {
        notificationService.cancelTaskNotifications(for: taskId)
        calendarService.removeTaskFromCalendar(taskId: taskId)
    }

    func taskCompleted(taskId: Int) {
        notificationService.cancelTaskNotifications(for: taskId)
        calendarService.removeTaskFromCalendar(taskId: taskId)
    }

    func taskReopened(_ task: TaskDTO) {
        notificationService.scheduleTaskNotifications(for: task)
        calendarService.addTaskToCalendar(task)
    }
}
