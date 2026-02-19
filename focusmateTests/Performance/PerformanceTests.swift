import XCTest
@testable import focusmate

/// Performance tests for critical code paths
/// Run with: Cmd+U or `xcodebuild test -scheme focusmate -only-testing:focusmateTests/PerformanceTests`
final class PerformanceTests: XCTestCase {

    // MARK: - Task Grouping Performance

    /// Tests groupedTasks computation with 50 tasks
    func testGroupedTasksPerformance_50Tasks() throws {
        let tasks = generateTasks(count: 50)
        let todayData = makeTodayResponse(dueTodayTasks: tasks)

        measure {
            _ = groupTasks(from: todayData)
        }
    }

    /// Tests groupedTasks computation with 100 tasks
    func testGroupedTasksPerformance_100Tasks() throws {
        let tasks = generateTasks(count: 100)
        let todayData = makeTodayResponse(dueTodayTasks: tasks)

        measure {
            _ = groupTasks(from: todayData)
        }
    }

    /// Tests groupedTasks computation with 500 tasks (stress test)
    func testGroupedTasksPerformance_500Tasks() throws {
        let tasks = generateTasks(count: 500)
        let todayData = makeTodayResponse(dueTodayTasks: tasks)

        measure {
            _ = groupTasks(from: todayData)
        }
    }

    /// Tests groupedTasks computation with 1000 tasks (extreme stress test)
    func testGroupedTasksPerformance_1000Tasks() throws {
        let tasks = generateTasks(count: 1000)
        let todayData = makeTodayResponse(dueTodayTasks: tasks)

        measure {
            _ = groupTasks(from: todayData)
        }
    }

    // MARK: - Cache Performance

    /// Tests cache write performance with many entries
    func testCacheWritePerformance_100Entries() async throws {
        let cache = ResponseCache.shared
        await cache.invalidateAll()

        let options = XCTMeasureOptions()
        options.iterationCount = 5

        measure(options: options) {
            let expectation = self.expectation(description: "Cache writes")

            Task {
                for i in 0..<100 {
                    await cache.set("key-\(i)", value: "value-\(i)", ttl: 60)
                }
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 10)
        }

        await cache.invalidateAll()
    }

    /// Tests cache read performance with many entries
    func testCacheReadPerformance_100Entries() async throws {
        let cache = ResponseCache.shared
        await cache.invalidateAll()

        // Pre-populate cache
        for i in 0..<100 {
            await cache.set("key-\(i)", value: "value-\(i)", ttl: 60)
        }

        let options = XCTMeasureOptions()
        options.iterationCount = 5

        measure(options: options) {
            let expectation = self.expectation(description: "Cache reads")

            Task {
                for i in 0..<100 {
                    let _: String? = await cache.get("key-\(i)")
                }
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 10)
        }

        await cache.invalidateAll()
    }

    /// Tests cache with complex DTO objects
    func testCachePerformance_DTOArrays() async throws {
        let cache = ResponseCache.shared
        await cache.invalidateAll()

        let lists = (0..<50).map { TestFactories.makeSampleList(id: $0, name: "List \($0)") }

        let options = XCTMeasureOptions()
        options.iterationCount = 5

        measure(options: options) {
            let expectation = self.expectation(description: "DTO cache ops")

            Task {
                // Write
                await cache.set("lists", value: lists, ttl: 60)
                // Read
                let _: [ListDTO]? = await cache.get("lists")
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 10)
        }

        await cache.invalidateAll()
    }

    // MARK: - Date Parsing Performance

    /// Tests ISO8601 date parsing performance (used heavily in task processing)
    func testDateParsingPerformance() throws {
        let isoStrings = (0..<100).map { i -> String in
            let hour = i % 24
            return "2024-01-15T\(String(format: "%02d", hour)):00:00Z"
        }

        let formatter = ISO8601DateFormatter()

        measure {
            for str in isoStrings {
                _ = formatter.date(from: str)
            }
        }
    }

    /// Tests task dueDate computed property performance
    func testTaskDueDateParsingPerformance() throws {
        let tasks = generateTasks(count: 100)

        measure {
            for task in tasks {
                _ = task.dueDate
            }
        }
    }

    // MARK: - Task Filtering Performance

    /// Tests filtering overdue tasks from a large list
    func testOverdueFilterPerformance_500Tasks() throws {
        let tasks = generateTasks(count: 500, overduePercentage: 0.2)

        measure {
            let overdue = tasks.filter { $0.isActuallyOverdue }
            _ = overdue.count
        }
    }

    /// Tests filtering completed tasks
    func testCompletedFilterPerformance_500Tasks() throws {
        let tasks = generateTasks(count: 500, completedPercentage: 0.5)

        measure {
            let completed = tasks.filter { $0.isCompleted }
            let incomplete = tasks.filter { !$0.isCompleted }
            _ = completed.count + incomplete.count
        }
    }

    // MARK: - Sorting Performance

    /// Tests sorting tasks by due date
    func testTaskSortingByDueDate_500Tasks() throws {
        let tasks = generateTasks(count: 500)

        measure {
            let sorted = tasks.sorted { t1, t2 in
                guard let d1 = t1.dueDate else { return false }
                guard let d2 = t2.dueDate else { return true }
                return d1 < d2
            }
            _ = sorted.count
        }
    }

    /// Tests sorting tasks by priority then due date
    func testTaskSortingByPriorityAndDueDate_500Tasks() throws {
        let tasks = generateTasks(count: 500)

        measure {
            let sorted = tasks.sorted { t1, t2 in
                let p1 = t1.priority ?? 0
                let p2 = t2.priority ?? 0
                if p1 != p2 { return p1 > p2 }
                guard let d1 = t1.dueDate else { return false }
                guard let d2 = t2.dueDate else { return true }
                return d1 < d2
            }
            _ = sorted.count
        }
    }

    // MARK: - Memory Baseline

    /// Baseline test to measure memory footprint of task arrays
    func testMemoryFootprint_1000Tasks() throws {
        measure(metrics: [XCTMemoryMetric()]) {
            let tasks = generateTasks(count: 1000)
            _ = tasks.count
        }
    }

    // MARK: - Helpers

    /// Generates test tasks with various due times throughout the day
    private func generateTasks(
        count: Int,
        overduePercentage: Double = 0,
        completedPercentage: Double = 0
    ) -> [TaskDTO] {
        let calendar = Calendar.current
        let today = Date()

        return (0..<count).map { i in
            let hour = i % 24
            let minute = (i * 7) % 60

            // Determine due date
            let dueDate: Date?
            if i % 10 == 0 {
                // 10% are "anytime" (midnight)
                dueDate = calendar.startOfDay(for: today)
            } else if Double(i) / Double(count) < overduePercentage {
                // Overdue tasks (yesterday)
                dueDate = calendar.date(byAdding: .day, value: -1, to: today)
            } else {
                // Regular tasks with specific times today
                var components = calendar.dateComponents([.year, .month, .day], from: today)
                components.hour = hour
                components.minute = minute
                dueDate = calendar.date(from: components)
            }

            let dueAtString = dueDate.map { TestFactories.isoFormatter.string(from: $0) }

            // Determine completion status
            let isCompleted = Double(i) / Double(count) < completedPercentage
            let completedAt = isCompleted ? TestFactories.isoFormatter.string(from: Date()) : nil

            return TestFactories.makeSampleTask(
                id: i,
                listId: (i % 5) + 1,
                title: "Task \(i)",
                dueAt: dueAtString,
                completedAt: completedAt,
                priority: i % 4,
                starred: i % 7 == 0,
                overdue: Double(i) / Double(count) < overduePercentage
            )
        }
    }

    /// Creates a TodayResponse with the given tasks
    private func makeTodayResponse(
        dueTodayTasks: [TaskDTO] = [],
        overdueTasks: [TaskDTO] = [],
        completedTasks: [TaskDTO] = []
    ) -> TodayResponse {
        TodayResponse(
            overdue: overdueTasks,
            has_more_overdue: nil,
            due_today: dueTodayTasks,
            completed_today: completedTasks,
            stats: nil,
            streak: nil
        )
    }

    /// Replicates the groupedTasks logic from TodayViewModel for isolated testing
    // swiftlint:disable:next large_tuple
    private func groupTasks(from data: TodayResponse) -> (anytime: [TaskDTO], morning: [TaskDTO], afternoon: [TaskDTO], evening: [TaskDTO]) {
        var anytime: [TaskDTO] = [], morning: [TaskDTO] = []
        var afternoon: [TaskDTO] = [], evening: [TaskDTO] = []
        let calendar = Calendar.current

        for task in data.due_today {
            guard let dueDate = task.dueDate else {
                anytime.append(task)
                continue
            }
            let hour = calendar.component(.hour, from: dueDate)
            let minute = calendar.component(.minute, from: dueDate)

            if hour == 0 && minute == 0 {
                anytime.append(task)
            } else if hour < 12 {
                morning.append(task)
            } else if hour < 17 {
                afternoon.append(task)
            } else {
                evening.append(task)
            }
        }
        return (anytime, morning, afternoon, evening)
    }
}
