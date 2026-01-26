import XCTest
@testable import focusmate

@MainActor
final class EscalationServiceTests: XCTestCase {

    private var sut: EscalationService!

    private let gracePeriodStartKey = "Escalation_GracePeriodStart"
    private let overdueTaskIdsKey = "Escalation_OverdueTaskIds"

    override func setUp() {
        super.setUp()
        sut = EscalationService.shared
        sut.resetAll()
        // Clear persisted state
        UserDefaults.standard.removeObject(forKey: gracePeriodStartKey)
        UserDefaults.standard.removeObject(forKey: overdueTaskIdsKey)
    }

    override func tearDown() {
        sut.resetAll()
        UserDefaults.standard.removeObject(forKey: gracePeriodStartKey)
        UserDefaults.standard.removeObject(forKey: overdueTaskIdsKey)
        super.tearDown()
    }

    // MARK: - resetAll

    func testResetAllClearsGracePeriod() {
        // Manually set state then reset
        sut.resetAll()
        XCTAssertFalse(sut.isInGracePeriod)
        XCTAssertNil(sut.gracePeriodEndTime)
    }

    func testResetAllClearsOverdueTaskIds() {
        let task = TestFactories.makeSampleTask(id: 42)
        sut.taskBecameOverdue(task)
        XCTAssertFalse(sut.overdueTaskIds.isEmpty)

        sut.resetAll()
        XCTAssertTrue(sut.overdueTaskIds.isEmpty)
    }

    func testResetAllClearsPersistedState() {
        let task = TestFactories.makeSampleTask(id: 10)
        sut.taskBecameOverdue(task)

        sut.resetAll()

        let persistedIds = UserDefaults.standard.array(forKey: overdueTaskIdsKey) as? [Int]
        XCTAssertTrue(persistedIds?.isEmpty ?? true)
    }

    // MARK: - taskBecameOverdue

    func testTaskBecameOverdueAddsTaskId() {
        let task = TestFactories.makeSampleTask(id: 5)
        sut.taskBecameOverdue(task)
        XCTAssertTrue(sut.overdueTaskIds.contains(5))
    }

    func testTaskBecameOverdueDoesNotAddDuplicate() {
        let task = TestFactories.makeSampleTask(id: 5)
        sut.taskBecameOverdue(task)
        sut.taskBecameOverdue(task)
        XCTAssertEqual(sut.overdueTaskIds.count, 1)
    }

    func testTaskBecameOverdueDoesNotStartGracePeriodWhenNotAuthorized() {
        // In test environment, ScreenTimeService won't be authorized
        let task = TestFactories.makeSampleTask(id: 5)
        sut.taskBecameOverdue(task)

        // Grace period should NOT start because ScreenTimeService.shared.isAuthorized is false
        XCTAssertFalse(sut.isInGracePeriod)
        XCTAssertNil(sut.gracePeriodEndTime)
    }

    func testTaskBecameOverduePersistsIds() {
        let task = TestFactories.makeSampleTask(id: 15)
        sut.taskBecameOverdue(task)

        let persistedIds = UserDefaults.standard.array(forKey: overdueTaskIdsKey) as? [Int]
        XCTAssertNotNil(persistedIds)
        XCTAssertTrue(persistedIds?.contains(15) ?? false)
    }

    // MARK: - taskCompleted

    func testTaskCompletedRemovesId() {
        let task = TestFactories.makeSampleTask(id: 8)
        sut.taskBecameOverdue(task)
        XCTAssertTrue(sut.overdueTaskIds.contains(8))

        sut.taskCompleted(8)
        XCTAssertFalse(sut.overdueTaskIds.contains(8))
    }

    func testTaskCompletedStopsEscalationWhenLastTask() {
        let task = TestFactories.makeSampleTask(id: 8)
        sut.taskBecameOverdue(task)

        sut.taskCompleted(8)

        XCTAssertTrue(sut.overdueTaskIds.isEmpty)
        XCTAssertFalse(sut.isInGracePeriod)
    }

    // MARK: - gracePeriodRemaining

    func testGracePeriodRemainingNilWhenNoGracePeriod() {
        XCTAssertNil(sut.gracePeriodRemaining)
    }

    func testGracePeriodRemainingFormattedNilWhenNoGracePeriod() {
        XCTAssertNil(sut.gracePeriodRemainingFormatted)
    }
}
