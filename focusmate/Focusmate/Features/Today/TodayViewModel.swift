import Foundation

@MainActor
@Observable
final class TodayViewModel {
    let taskService: TaskService
    let listService: ListService
    let tagService: TagService
    let escalationService: EscalationService
    let screenTimeService: ScreenTimeService
    private let notificationService: NotificationService
    private var todayService: TodayService?
    private let apiClient: APIClient

    var todayData: TodayResponse?
    var isLoading = true
    var error: FocusmateError?
    var showingQuickAdd = false
    var selectedTask: TaskDTO?

    // Subtask sheets
    var taskForSubtask: TaskDTO?
    var subtaskEditInfo: SubtaskEditInfo?

    var onOverdueCountChange: ((Int) -> Void)?

    // MARK: - Computed Properties

    var totalTasks: Int {
        guard let data = todayData else { return 0 }
        return data.overdue.count + data.due_today.count + data.completed_today.count
    }

    var completedCount: Int {
        todayData?.completed_today.count ?? 0
    }

    var progress: Double {
        guard totalTasks > 0 else { return 0 }
        return Double(completedCount) / Double(totalTasks)
    }

    var isAllComplete: Bool {
        guard let data = todayData else { return false }
        return data.overdue.isEmpty && data.due_today.isEmpty && !data.completed_today.isEmpty
    }

    var groupedTasks: (anytime: [TaskDTO], morning: [TaskDTO], afternoon: [TaskDTO], evening: [TaskDTO]) {
        guard let data = todayData else { return ([], [], [], []) }
        var anytime: [TaskDTO] = [], morning: [TaskDTO] = []
        var afternoon: [TaskDTO] = [], evening: [TaskDTO] = []
        let calendar = Calendar.current
        for task in data.due_today {
            guard let dueDate = task.dueDate else { anytime.append(task); continue }
            let hour = calendar.component(.hour, from: dueDate)
            let minute = calendar.component(.minute, from: dueDate)
            if hour == 0 && minute == 0 { anytime.append(task) }
            else if hour < 12 { morning.append(task) }
            else if hour < 17 { afternoon.append(task) }
            else { evening.append(task) }
        }
        return (anytime, morning, afternoon, evening)
    }

    // MARK: - Init

    init(
        taskService: TaskService,
        listService: ListService,
        tagService: TagService,
        apiClient: APIClient,
        escalationService: EscalationService? = nil,
        screenTimeService: ScreenTimeService? = nil,
        notificationService: NotificationService? = nil
    ) {
        self.taskService = taskService
        self.listService = listService
        self.tagService = tagService
        self.apiClient = apiClient
        self.escalationService = escalationService ?? .shared
        self.screenTimeService = screenTimeService ?? .shared
        self.notificationService = notificationService ?? .shared
    }

    // MARK: - Actions

    func initializeServiceIfNeeded() {
        if todayService == nil {
            todayService = TodayService(api: apiClient)
        }
    }

    func loadToday() async {
        isLoading = todayData == nil
        error = nil

        do {
            guard let todayService else { return }
            todayData = try await todayService.fetchToday()
            onOverdueCountChange?(todayData?.stats?.overdue_count ?? 0)

            let totalDueToday = (todayData?.stats?.due_today_count ?? 0) + (todayData?.stats?.overdue_count ?? 0)
            notificationService.scheduleMorningBriefing(taskCount: totalDueToday)
        } catch {
            self.error = ErrorHandler.shared.handle(error, context: "Loading Today")
        }

        isLoading = false
    }

    func toggleComplete(_ task: TaskDTO) async {
        if task.isCompleted {
            do {
                _ = try await taskService.reopenTask(listId: task.list_id, taskId: task.id)
                await loadToday()
            } catch {
                Logger.error("Failed to reopen task", error: error, category: .api)
            }
        } else {
            await loadToday()
        }
    }

    func deleteTask(_ task: TaskDTO) async {
        do {
            try await taskService.deleteTask(listId: task.list_id, taskId: task.id)
            await loadToday()
        } catch {
            Logger.error("Failed to delete task", error: error, category: .api)
        }
    }

    // MARK: - Subtask Actions

    func startAddSubtask(for task: TaskDTO) {
        taskForSubtask = task
    }

    func startEditSubtask(_ subtask: SubtaskDTO, parentTask: TaskDTO) {
        subtaskEditInfo = SubtaskEditInfo(subtask: subtask, parentTask: parentTask)
    }

    func createSubtask(parentTask: TaskDTO, title: String) async {
        do {
            _ = try await taskService.createSubtask(
                listId: parentTask.list_id,
                parentTaskId: parentTask.id,
                title: title
            )
            HapticManager.success()
            await loadToday()
        } catch {
            Logger.error("Failed to create subtask", error: error, category: .api)
        }
    }

    func updateSubtask(info: SubtaskEditInfo, title: String) async {
        do {
            _ = try await taskService.updateSubtask(
                listId: info.parentTask.list_id,
                parentTaskId: info.parentTask.id,
                subtaskId: info.subtask.id,
                title: title
            )
            HapticManager.success()
            await loadToday()
        } catch {
            Logger.error("Failed to update subtask", error: error, category: .api)
        }
    }
}
