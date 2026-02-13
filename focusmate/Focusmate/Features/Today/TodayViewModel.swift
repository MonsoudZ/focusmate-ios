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
    private var loadVersion = 0

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

    private(set) var groupedTasks: (anytime: [TaskDTO], morning: [TaskDTO], afternoon: [TaskDTO], evening: [TaskDTO]) = ([], [], [], [])

    // MARK: - Private Helpers

    /// Recompute the time-of-day grouping from todayData.
    /// Called once per data load instead of on every body evaluation — avoids
    /// redundant O(n) Calendar lookups during SwiftUI render cycles.
    private func recomputeGroupedTasks() {
        guard let data = todayData else {
            groupedTasks = ([], [], [], [])
            return
        }
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
        groupedTasks = (anytime, morning, afternoon, evening)
    }

    // MARK: - Timezone Guard

    /// Remove tasks that clearly don't belong to "today" in the device timezone.
    ///
    /// **Design choice — guard, not re-bucket.**  The server owns bucketing logic
    /// (overdue vs. due_today, grace periods, etc.).  Re-implementing that here
    /// creates two sources of truth that drift apart.  Instead, this method only
    /// *removes* tasks whose calendar day is clearly wrong — tomorrow or later
    /// leaked into due_today, or future-dated tasks leaked into overdue.  The
    /// server's internal split between overdue and due_today is preserved.
    ///
    /// **What this catches:** The server computes "start of today" from the
    /// `users.timezone` column.  If the device is UTC-5 but the server thinks
    /// UTC, the server's midnight is 5 hours ahead.  A task due tomorrow in the
    /// user's timezone might slip through as "due today" server-side.  This guard
    /// strips those leaks without re-inventing overdue logic.
    ///
    /// **What this deliberately does NOT do:**
    /// - Move tasks between overdue ↔ due_today (server's call)
    /// - Re-define "overdue" with client-side time checks
    /// - Touch completed_today (completion timestamps are authoritative)
    ///
    /// **Tradeoff:** If the server sends a task that's *actually* today in the
    /// user's TZ but falls on a different calendar day due to rounding, this
    /// guard could remove it.  Layers 1+2 (timezone sync + query param) make
    /// that window extremely narrow.
    private func removeOutOfDayTasks(_ response: TodayResponse) -> TodayResponse {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        guard let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) else {
            return response
        }

        func belongsToTodayOrEarlier(_ task: TaskDTO) -> Bool {
            guard let dueDate = task.dueDate else { return true }
            let taskDay = calendar.startOfDay(for: dueDate)
            return taskDay < startOfTomorrow
        }

        func belongsToTodayOrEarlierForOverdue(_ task: TaskDTO) -> Bool {
            guard let dueDate = task.dueDate else { return true }
            let taskDay = calendar.startOfDay(for: dueDate)
            // Overdue tasks should be today or earlier — reject future tasks
            return taskDay < startOfTomorrow
        }

        let filteredOverdue = response.overdue.filter { belongsToTodayOrEarlierForOverdue($0) }
        let filteredDueToday = response.due_today.filter { belongsToTodayOrEarlier($0) }

        // Only rebuild stats if we actually removed something
        if filteredOverdue.count == response.overdue.count &&
            filteredDueToday.count == response.due_today.count {
            return response
        }

        return TodayResponse(
            overdue: filteredOverdue,
            due_today: filteredDueToday,
            completed_today: response.completed_today,
            stats: TodayStats(
                overdue_count: filteredOverdue.count,
                due_today_count: filteredDueToday.count,
                completed_today_count: response.completed_today.count
            ),
            streak: response.streak
        )
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

    /// Load today data, using a version counter to discard stale responses.
    ///
    /// Two overlapping calls (e.g. pull-to-refresh during a debounced subtask
    /// reload) race at the await point. Without protection, whichever API
    /// response arrives last writes todayData — if the older call finishes
    /// second, it overwrites fresher data. The version counter ensures only
    /// the most recent call's result is applied; superseded calls bail out
    /// silently after the await.
    func loadToday() async {
        guard let todayService else { return }

        loadVersion += 1
        let myVersion = loadVersion

        isLoading = todayData == nil
        error = nil

        do {
            let raw = try await todayService.fetchToday()
            guard myVersion == loadVersion else { return }
            let data = removeOutOfDayTasks(raw)
            todayData = data
            recomputeGroupedTasks()
            onOverdueCountChange?(todayData?.stats?.overdue_count ?? 0)

            let totalDueToday = (todayData?.stats?.due_today_count ?? 0) + (todayData?.stats?.overdue_count ?? 0)
            notificationService.scheduleMorningBriefing(taskCount: totalDueToday)
        } catch {
            guard myVersion == loadVersion else { return }
            self.error = ErrorHandler.shared.handle(error, context: "Loading Today")
        }

        guard myVersion == loadVersion else { return }
        isLoading = false
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
            } catch where NetworkMonitor.isOfflineError(error) {
                let svc = self.taskService
                let listId = task.list_id, taskId = task.id
                await MutationQueue.shared.enqueue(description: "Reopen task") {
                    _ = try await svc.reopenTask(listId: listId, taskId: taskId)
                }
            } catch {
                Logger.error("Failed to reopen task", error: error, category: .api)
                self.error = ErrorHandler.shared.handle(error, context: "Reopening task")
            }
        } else {
            do {
                _ = try await taskService.completeTask(listId: task.list_id, taskId: task.id, reason: reason)
                HapticManager.success()
                await reloadAfterMutation()
            } catch where NetworkMonitor.isOfflineError(error) {
                HapticManager.success()
                let svc = self.taskService
                let listId = task.list_id, taskId = task.id
                await MutationQueue.shared.enqueue(description: "Complete task") {
                    _ = try await svc.completeTask(listId: listId, taskId: taskId, reason: reason)
                }
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
        } catch where NetworkMonitor.isOfflineError(error) {
            let svc = self.taskService
            let listId = task.list_id, taskId = task.id
            await MutationQueue.shared.enqueue(description: "Delete task") {
                try await svc.deleteTask(listId: listId, taskId: taskId)
            }
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
