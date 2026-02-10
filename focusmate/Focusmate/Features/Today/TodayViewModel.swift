import Combine
import Foundation
import SwiftUI

@MainActor
@Observable
final class TodayViewModel {
    let taskService: TaskService
    let listService: ListService
    let tagService: TagService
    let escalationService: EscalationService
    let screenTimeService: ScreenTimeService
    private let notificationService: NotificationService
    private let subtaskManager: SubtaskManager
    private var todayService: TodayService?
    private let apiClient: APIClient
    private var cancellables = Set<AnyCancellable>()

    var todayData: TodayResponse?
    var isLoading = true
    var error: FocusmateError?
    var nudgeMessage: String?

    var onOverdueCountChange: ((Int) -> Void)?
    private var inFlightTaskIds = Set<Int>()

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
        subtaskManager: SubtaskManager,
        escalationService: EscalationService? = nil,
        screenTimeService: ScreenTimeService? = nil,
        notificationService: NotificationService? = nil
    ) {
        self.taskService = taskService
        self.listService = listService
        self.tagService = tagService
        self.apiClient = apiClient
        self.subtaskManager = subtaskManager
        self.escalationService = escalationService ?? .shared
        self.screenTimeService = screenTimeService ?? .shared
        self.notificationService = notificationService ?? .shared

        // Subscribe to subtask changes and reload data.
        // Debounce coalesces rapid-fire subtask mutations (e.g. toggling several
        // checkboxes quickly) into a single API reload, preventing redundant
        // concurrent fetches that could race and show stale data.
        subtaskManager.changePublisher
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.loadToday() }
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    func initializeServiceIfNeeded() {
        if todayService == nil {
            todayService = TodayService(api: apiClient)
        }
    }

    func loadToday() async {
        guard let todayService else { return }

        isLoading = todayData == nil
        error = nil
        defer { isLoading = false }

        do {
            todayData = try await todayService.fetchToday()
            onOverdueCountChange?(todayData?.stats?.overdue_count ?? 0)

            let totalDueToday = (todayData?.stats?.due_today_count ?? 0) + (todayData?.stats?.overdue_count ?? 0)
            notificationService.scheduleMorningBriefing(taskCount: totalDueToday)
        } catch {
            self.error = ErrorHandler.shared.handle(error, context: "Loading Today")
        }
    }

    /// Invalidate cached today data and reload fresh from server.
    /// Called after mutations to ensure cache coherence (write invalidates read cache).
    private func reloadAfterMutation() async {
        await todayService?.invalidateCache()
        await loadToday()
    }

    func toggleComplete(_ task: TaskDTO, reason: String? = nil) async {
        guard inFlightTaskIds.insert(task.id).inserted else { return }
        defer { inFlightTaskIds.remove(task.id) }

        if task.isCompleted {
            do {
                _ = try await taskService.reopenTask(listId: task.list_id, taskId: task.id)
                await reloadAfterMutation()
            } catch {
                Logger.error("Failed to reopen task", error: error, category: .api)
                self.error = ErrorHandler.shared.handle(error, context: "Reopening task")
            }
        } else {
            do {
                _ = try await taskService.completeTask(listId: task.list_id, taskId: task.id, reason: reason)
                HapticManager.success()
                await reloadAfterMutation()
            } catch {
                Logger.error("Failed to complete task", error: error, category: .api)
                self.error = ErrorHandler.shared.handle(error, context: "Completing task")
            }
        }
    }

    func deleteTask(_ task: TaskDTO) async {
        guard inFlightTaskIds.insert(task.id).inserted else { return }
        defer { inFlightTaskIds.remove(task.id) }

        do {
            try await taskService.deleteTask(listId: task.list_id, taskId: task.id)
            await reloadAfterMutation()
        } catch {
            Logger.error("Failed to delete task", error: error, category: .api)
            self.error = ErrorHandler.shared.handle(error, context: "Deleting task")
        }
    }

    func toggleStar(_ task: TaskDTO) async {
        guard inFlightTaskIds.insert(task.id).inserted else { return }
        defer { inFlightTaskIds.remove(task.id) }

        do {
            _ = try await taskService.updateTask(
                listId: task.list_id,
                taskId: task.id,
                title: nil,
                note: nil,
                dueAt: nil,
                starred: !task.isStarred
            )
            HapticManager.light()
            await reloadAfterMutation()
        } catch {
            Logger.error("Failed to toggle star", error: error, category: .api)
            self.error = ErrorHandler.shared.handle(error, context: "Starring task")
        }
    }

    func nudgeTask(_ task: TaskDTO) async {
        do {
            try await taskService.nudgeTask(listId: task.list_id, taskId: task.id)
            HapticManager.success()
            withAnimation {
                nudgeMessage = "Nudge sent!"
            }
        } catch {
            Logger.error("Failed to nudge: \(error)", category: .api)
            HapticManager.error()
            withAnimation {
                nudgeMessage = "Couldn't send nudge"
            }
        }
    }

    // MARK: - Subtask Actions

    func createSubtask(parentTask: TaskDTO, title: String) async {
        do {
            _ = try await subtaskManager.create(parentTask: parentTask, title: title)
            // loadToday() is triggered automatically via changePublisher subscription
        } catch {
            Logger.error("Failed to create subtask", error: error, category: .api)
            self.error = ErrorHandler.shared.handle(error, context: "Creating subtask")
            HapticManager.error()
        }
    }

    func updateSubtask(info: SubtaskEditInfo, title: String) async {
        do {
            _ = try await subtaskManager.update(subtask: info.subtask, parentTask: info.parentTask, title: title)
            // loadToday() is triggered automatically via changePublisher subscription
        } catch {
            Logger.error("Failed to update subtask", error: error, category: .api)
            self.error = ErrorHandler.shared.handle(error, context: "Updating subtask")
            HapticManager.error()
        }
    }
}
