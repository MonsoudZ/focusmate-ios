@testable import focusmate
import XCTest

final class TaskDTOTests: XCTestCase {
  // MARK: - dueDate Parsing

  func testDueDateParsesISO8601WithFractionalSeconds() {
    let task = TestFactories.makeSampleTask(dueAt: "2024-06-15T14:30:00.123Z")
    XCTAssertNotNil(task.dueDate)
  }

  func testDueDateParsesISO8601WithoutFractionalSeconds() {
    let task = TestFactories.makeSampleTask(dueAt: "2024-06-15T14:30:00Z")
    XCTAssertNotNil(task.dueDate)
  }

  func testDueDateNilWhenMissing() {
    let task = TestFactories.makeSampleTask(dueAt: nil)
    XCTAssertNil(task.dueDate)
  }

  // MARK: - isActuallyOverdue

  func testIsActuallyOverdueForPastDueDate() {
    let pastDate = TestFactories.isoString(daysFromNow: -2, hour: 14)
    let task = TestFactories.makeSampleTask(dueAt: pastDate)
    XCTAssertTrue(task.isActuallyOverdue)
  }

  func testIsActuallyOverdueNotOverdueForFutureDate() {
    let futureDate = TestFactories.isoString(daysFromNow: 2, hour: 14)
    let task = TestFactories.makeSampleTask(dueAt: futureDate)
    XCTAssertFalse(task.isActuallyOverdue)
  }

  func testIsActuallyOverdueNotOverdueWhenCompleted() {
    let pastDate = TestFactories.isoString(daysFromNow: -2, hour: 14)
    let task = TestFactories.makeSampleTask(
      dueAt: pastDate,
      completedAt: "2024-06-15T14:30:00Z"
    )
    XCTAssertFalse(task.isActuallyOverdue)
  }

  func testIsActuallyOverdueNotOverdueWhenNoDueDate() {
    let task = TestFactories.makeSampleTask(dueAt: nil)
    XCTAssertFalse(task.isActuallyOverdue)
  }

  func testIsActuallyOverdueAnytimeTaskOverdueYesterday() {
    // Midnight yesterday in local timezone — the calendar day has fully passed
    let yesterdayMidnight = TestFactories.midnightISOString(daysFromNow: -1)
    let task = TestFactories.makeSampleTask(dueAt: yesterdayMidnight)
    XCTAssertTrue(task.isAnytime, "Precondition: task should be 'anytime'")
    XCTAssertTrue(task.isActuallyOverdue)
  }

  func testIsActuallyOverdueAnytimeTaskNotOverdueToday() {
    // Midnight today — still within today
    let todayMidnight = TestFactories.midnightISOString(daysFromNow: 0)
    let task = TestFactories.makeSampleTask(dueAt: todayMidnight)
    XCTAssertTrue(task.isAnytime, "Precondition: task should be 'anytime'")
    XCTAssertFalse(task.isActuallyOverdue)
  }

  // MARK: - isAnytime

  func testIsAnytimeTrueForMidnight() {
    let midnight = TestFactories.midnightISOString(daysFromNow: 0)
    let task = TestFactories.makeSampleTask(dueAt: midnight)
    XCTAssertTrue(task.isAnytime)
  }

  func testIsAnytimeFalseForSpecificTime() {
    let specific = TestFactories.isoString(daysFromNow: 0, hour: 14, minute: 30)
    let task = TestFactories.makeSampleTask(dueAt: specific)
    XCTAssertFalse(task.isAnytime)
  }

  func testIsAnytimeFalseWhenNoDueDate() {
    let task = TestFactories.makeSampleTask(dueAt: nil)
    XCTAssertFalse(task.isAnytime)
  }

  // MARK: - isCompleted

  func testIsCompletedTrueWhenCompletedAtSet() {
    let task = TestFactories.makeSampleTask(completedAt: "2024-06-15T14:30:00Z")
    XCTAssertTrue(task.isCompleted)
  }

  func testIsCompletedFalseWhenCompletedAtNil() {
    let task = TestFactories.makeSampleTask(completedAt: nil)
    XCTAssertFalse(task.isCompleted)
  }

  // MARK: - isOverdue (server flag)

  func testIsOverdueTrueWhenFlagSet() {
    let task = TestFactories.makeSampleTask(overdue: true)
    XCTAssertTrue(task.isOverdue)
  }

  func testIsOverdueFalseWhenFlagNil() {
    let task = TestFactories.makeSampleTask(overdue: nil)
    XCTAssertFalse(task.isOverdue)
  }

  // MARK: - isStarred

  func testIsStarredTrue() {
    let task = TestFactories.makeSampleTask(starred: true)
    XCTAssertTrue(task.isStarred)
  }

  func testIsStarredFalseWhenNil() {
    let task = TestFactories.makeSampleTask(starred: nil)
    XCTAssertFalse(task.isStarred)
  }

  // MARK: - isRecurring / isRecurringInstance

  func testIsRecurringTrue() {
    let task = TestFactories.makeSampleTask(isRecurring: true)
    XCTAssertTrue(task.isRecurring)
  }

  func testIsRecurringFalseWhenNil() {
    let task = TestFactories.makeSampleTask(isRecurring: nil)
    XCTAssertFalse(task.isRecurring)
  }

  func testIsRecurringInstanceTrue() {
    let task = TestFactories.makeSampleTask(templateId: 42)
    XCTAssertTrue(task.isRecurringInstance)
  }

  func testIsRecurringInstanceFalse() {
    let task = TestFactories.makeSampleTask(templateId: nil)
    XCTAssertFalse(task.isRecurringInstance)
  }

  // MARK: - recurrenceDescription

  func testRecurrenceDescriptionDaily() {
    let task = TestFactories.makeSampleTask(
      isRecurring: true,
      recurrencePattern: "daily",
      recurrenceInterval: 1
    )
    XCTAssertEqual(task.recurrenceDescription, "Daily")
  }

  func testRecurrenceDescriptionDailyCustomInterval() {
    let task = TestFactories.makeSampleTask(
      isRecurring: true,
      recurrencePattern: "daily",
      recurrenceInterval: 3
    )
    XCTAssertEqual(task.recurrenceDescription, "Every 3 days")
  }

  func testRecurrenceDescriptionWeekly() {
    let task = TestFactories.makeSampleTask(
      isRecurring: true,
      recurrencePattern: "weekly",
      recurrenceInterval: 1
    )
    XCTAssertEqual(task.recurrenceDescription, "Weekly")
  }

  func testRecurrenceDescriptionWeeklyWithDays() {
    let task = TestFactories.makeSampleTask(
      isRecurring: true,
      recurrencePattern: "weekly",
      recurrenceInterval: 1,
      recurrenceDays: [1, 3, 5]
    )
    XCTAssertEqual(task.recurrenceDescription, "Weekly on Mon, Wed, Fri")
  }

  func testRecurrenceDescriptionMonthly() {
    let task = TestFactories.makeSampleTask(
      isRecurring: true,
      recurrencePattern: "monthly",
      recurrenceInterval: 1
    )
    XCTAssertEqual(task.recurrenceDescription, "Monthly")
  }

  func testRecurrenceDescriptionYearly() {
    let task = TestFactories.makeSampleTask(
      isRecurring: true,
      recurrencePattern: "yearly",
      recurrenceInterval: 1
    )
    XCTAssertEqual(task.recurrenceDescription, "Yearly")
  }

  func testRecurrenceDescriptionNilWhenNotRecurring() {
    let task = TestFactories.makeSampleTask(isRecurring: nil, recurrencePattern: nil)
    XCTAssertNil(task.recurrenceDescription)
  }

  func testRecurrenceDescriptionForRecurringInstance() {
    let task = TestFactories.makeSampleTask(
      recurrencePattern: "monthly",
      recurrenceInterval: 2,
      templateId: 42
    )
    XCTAssertEqual(task.recurrenceDescription, "Every 2 months")
  }

  // MARK: - Subtask Helpers

  func testHasSubtasksTrue() {
    let sub = TestFactories.makeSampleSubtask()
    let task = TestFactories.makeSampleTask(subtasks: [sub])
    XCTAssertTrue(task.hasSubtasks)
  }

  func testHasSubtasksFalseWhenEmpty() {
    let task = TestFactories.makeSampleTask(subtasks: [])
    XCTAssertFalse(task.hasSubtasks)
  }

  func testHasSubtasksFalseWhenNil() {
    let task = TestFactories.makeSampleTask(subtasks: nil)
    XCTAssertFalse(task.hasSubtasks)
  }

  func testSubtaskProgressCountsCompletedVsTotal() {
    let completed = TestFactories.makeSampleSubtask(id: 1, completedAt: "2024-01-01T00:00:00Z")
    let pending = TestFactories.makeSampleSubtask(id: 2, completedAt: nil)
    let task = TestFactories.makeSampleTask(subtasks: [completed, pending])
    XCTAssertEqual(task.subtaskProgress, "1/2")
    XCTAssertEqual(task.subtaskCount, 2)
    XCTAssertEqual(task.completedSubtaskCount, 1)
  }

  func testSubtaskProgressEmptySubtasks() {
    let task = TestFactories.makeSampleTask(subtasks: [])
    XCTAssertEqual(task.subtaskProgress, "0/0")
  }

  func testSubtaskProgressNilSubtasks() {
    let task = TestFactories.makeSampleTask(subtasks: nil)
    XCTAssertEqual(task.subtaskProgress, "0/0")
  }

  // MARK: - isSubtask

  func testIsSubtaskTrueWhenParentIdSet() {
    let task = TestFactories.makeSampleTask(parentTaskId: 42)
    XCTAssertTrue(task.isSubtask)
  }

  func testIsSubtaskFalseWhenParentIdNil() {
    let task = TestFactories.makeSampleTask(parentTaskId: nil)
    XCTAssertFalse(task.isSubtask)
  }

  // MARK: - needsReason

  func testNeedsReasonTrueWhenOverdueAndRequiresExplanation() {
    let task = TestFactories.makeSampleTask(
      overdue: true,
      requiresExplanationIfMissed: true,
      missedReason: nil
    )
    XCTAssertTrue(task.needsReason)
  }

  func testNeedsReasonFalseWhenReasonAlreadyProvided() {
    let task = TestFactories.makeSampleTask(
      overdue: true,
      requiresExplanationIfMissed: true,
      missedReason: "Was sick"
    )
    XCTAssertFalse(task.needsReason)
  }

  func testNeedsReasonFalseWhenNotOverdue() {
    let task = TestFactories.makeSampleTask(
      overdue: false,
      requiresExplanationIfMissed: true
    )
    XCTAssertFalse(task.needsReason)
  }

  // MARK: - TaskPriority

  func testTaskPriorityRawValues() {
    XCTAssertEqual(TaskPriority.none.rawValue, 0)
    XCTAssertEqual(TaskPriority.low.rawValue, 1)
    XCTAssertEqual(TaskPriority.medium.rawValue, 2)
    XCTAssertEqual(TaskPriority.high.rawValue, 3)
    XCTAssertEqual(TaskPriority.urgent.rawValue, 4)
  }

  func testTaskPriorityOrdering() {
    XCTAssertTrue(TaskPriority.none.rawValue < TaskPriority.low.rawValue)
    XCTAssertTrue(TaskPriority.low.rawValue < TaskPriority.medium.rawValue)
    XCTAssertTrue(TaskPriority.medium.rawValue < TaskPriority.high.rawValue)
    XCTAssertTrue(TaskPriority.high.rawValue < TaskPriority.urgent.rawValue)
  }

  func testTaskPriorityCaseIterable() {
    XCTAssertEqual(TaskPriority.allCases.count, 5)
  }

  func testTaskPriorityComputedFromDTO() {
    let task = TestFactories.makeSampleTask(priority: 3)
    XCTAssertEqual(task.taskPriority, .high)
  }

  func testTaskPriorityDefaultsToNone() {
    let task = TestFactories.makeSampleTask(priority: nil)
    XCTAssertEqual(task.taskPriority, .none)
  }
}
