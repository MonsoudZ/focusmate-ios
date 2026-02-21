import XCTest
@testable import focusmate

/// Integration tests for EscalationService covering full lifecycle flows.
///
/// The existing EscalationServiceTests cover individual state transitions.
/// These tests verify multi-step sequences that exercise the state machine
/// end-to-end: overdue → grace period → blocking → completion → reset.
@MainActor
final class EscalationServiceIntegrationTests: XCTestCase {

    private var sut: EscalationService!
    private var mockScreenTime: MockScreenTimeService!

    private let gracePeriodStartKey = SharedDefaults.gracePeriodStartTimeKey
    private let overdueTaskIdsKey = SharedDefaults.overdueTaskIdsKey
    private var store: UserDefaults { SharedDefaults.store }

    override func setUp() {
        super.setUp()
        store.removeObject(forKey: gracePeriodStartKey)
        store.removeObject(forKey: overdueTaskIdsKey)
        mockScreenTime = MockScreenTimeService()
        sut = EscalationService(screenTimeService: mockScreenTime)
    }

    override func tearDown() {
        sut.resetAll()
        store.removeObject(forKey: gracePeriodStartKey)
        store.removeObject(forKey: overdueTaskIdsKey)
        super.tearDown()
    }

    // MARK: - Full Lifecycle: Overdue → Grace Period → Task Completed

    func testOverdueTaskCompletedDuringGracePeriodStopsEscalation() {
        let task = TestFactories.makeSampleTask(id: 1)

        // Task becomes overdue → grace period starts
        sut.taskBecameOverdue(task)
        XCTAssertTrue(sut.isInGracePeriod)
        XCTAssertTrue(sut.overdueTaskIds.contains(1))
        XCTAssertFalse(mockScreenTime.startBlockingCalled, "Should not block during grace period")

        // Task completed during grace period → escalation stops entirely
        sut.taskCompleted(1)
        XCTAssertTrue(sut.overdueTaskIds.isEmpty)
        XCTAssertFalse(sut.isInGracePeriod)
        XCTAssertFalse(mockScreenTime.startBlockingCalled, "Blocking should never have started")
    }

    // MARK: - Multiple Tasks: Partial Completion

    func testMultipleOverdueTasksPartialCompletionKeepsEscalation() {
        let task1 = TestFactories.makeSampleTask(id: 1)
        let task2 = TestFactories.makeSampleTask(id: 2)
        let task3 = TestFactories.makeSampleTask(id: 3)

        sut.taskBecameOverdue(task1)
        sut.taskBecameOverdue(task2)
        sut.taskBecameOverdue(task3)

        XCTAssertEqual(sut.overdueTaskIds.count, 3)
        XCTAssertTrue(sut.isInGracePeriod)

        // Complete one task — escalation continues
        sut.taskCompleted(1)
        XCTAssertEqual(sut.overdueTaskIds.count, 2)
        XCTAssertTrue(sut.overdueTaskIds.contains(2))
        XCTAssertTrue(sut.overdueTaskIds.contains(3))

        // Complete second task — escalation continues
        sut.taskCompleted(2)
        XCTAssertEqual(sut.overdueTaskIds.count, 1)

        // Complete last task — escalation stops
        sut.taskCompleted(3)
        XCTAssertTrue(sut.overdueTaskIds.isEmpty)
        XCTAssertFalse(sut.isInGracePeriod)
    }

    // MARK: - Authorization Revoked During Escalation

    func testAuthorizationRevokedDuringEscalationResetsAndSetsFlag() {
        let task = TestFactories.makeSampleTask(id: 10)
        sut.taskBecameOverdue(task)
        XCTAssertTrue(sut.isInGracePeriod)
        XCTAssertFalse(sut.authorizationWasRevoked)

        // User revokes Screen Time in iOS Settings while app is backgrounded
        mockScreenTime.isAuthorized = false
        sut.checkAuthorizationRevocation()

        // State fully reset, but revocation flag survives for recovery banner
        XCTAssertTrue(sut.overdueTaskIds.isEmpty)
        XCTAssertFalse(sut.isInGracePeriod)
        XCTAssertTrue(sut.authorizationWasRevoked)
        XCTAssertTrue(mockScreenTime.stopBlockingCalled)
    }

    func testAuthorizationRevokedThenReGrantedClearsFlag() {
        let task = TestFactories.makeSampleTask(id: 10)
        sut.taskBecameOverdue(task)
        mockScreenTime.isAuthorized = false
        sut.checkAuthorizationRevocation()
        XCTAssertTrue(sut.authorizationWasRevoked)

        // User re-grants authorization in iOS Settings
        mockScreenTime.isAuthorized = true
        sut.checkAuthorizationRevocation()

        // Flag auto-clears — user fixed the problem
        XCTAssertFalse(sut.authorizationWasRevoked)
    }

    func testResetAllPreservesRevocationFlag() {
        let task = TestFactories.makeSampleTask(id: 10)
        sut.taskBecameOverdue(task)
        mockScreenTime.isAuthorized = false
        sut.checkAuthorizationRevocation()
        XCTAssertTrue(sut.authorizationWasRevoked)

        // resetAll (e.g. from sign-out) should NOT clear the flag
        sut.resetAll()
        XCTAssertTrue(sut.authorizationWasRevoked)
        XCTAssertTrue(sut.overdueTaskIds.isEmpty)
    }

    // MARK: - No Authorization: Escalation Skipped

    func testOverdueWithoutAuthorizationDoesNotStartGracePeriod() {
        mockScreenTime.isAuthorized = false
        let task = TestFactories.makeSampleTask(id: 5)

        sut.taskBecameOverdue(task)

        // Task tracked but no grace period
        XCTAssertTrue(sut.overdueTaskIds.contains(5))
        XCTAssertFalse(sut.isInGracePeriod)
        XCTAssertNil(sut.gracePeriodEndTime)
    }

    func testOverdueWithoutAppSelectionsDoesNotStartGracePeriod() {
        mockScreenTime.hasSelections = false
        let task = TestFactories.makeSampleTask(id: 5)

        sut.taskBecameOverdue(task)

        XCTAssertTrue(sut.overdueTaskIds.contains(5))
        XCTAssertFalse(sut.isInGracePeriod)
    }

    // MARK: - Persistence and Restoration

    func testOverdueTaskIdsPersistToUserDefaults() {
        // Verify the persistence contract: taskBecameOverdue saves to UserDefaults
        // and resetAll clears it. A new EscalationService instance reads from the
        // same keys on init (verified by loadState in init). We test the write/read
        // contract without creating a second live instance, since EscalationService
        // uses @Published + Timer on the main run loop and multiple live instances
        // trigger a malloc double-free in the test host.
        let task1 = TestFactories.makeSampleTask(id: 42)
        let task2 = TestFactories.makeSampleTask(id: 99)

        sut.taskBecameOverdue(task1)
        sut.taskBecameOverdue(task2)

        // Verify persistence write
        let persistedIds = store.array(forKey: overdueTaskIdsKey) as? [Int]
        XCTAssertNotNil(persistedIds, "Overdue task IDs should be persisted")
        XCTAssertTrue(persistedIds?.contains(42) ?? false)
        XCTAssertTrue(persistedIds?.contains(99) ?? false)

        // Verify grace period start was persisted
        let gracePeriodStart = store.object(forKey: gracePeriodStartKey) as? Date
        XCTAssertNotNil(gracePeriodStart, "Grace period start should be persisted")

        // Verify resetAll clears persisted state
        sut.resetAll()
        let clearedIds = store.array(forKey: overdueTaskIdsKey) as? [Int]
        XCTAssertTrue(clearedIds?.isEmpty ?? true, "resetAll should clear persisted IDs")
        XCTAssertNil(store.object(forKey: gracePeriodStartKey))
    }

    func testResetAllClearsPersistedState() {
        let task = TestFactories.makeSampleTask(id: 42)
        sut.taskBecameOverdue(task)

        sut.resetAll()

        // Verify shared store is clean
        let persistedIds = store.array(forKey: overdueTaskIdsKey) as? [Int]
        XCTAssertTrue(persistedIds?.isEmpty ?? true)
        XCTAssertNil(store.object(forKey: gracePeriodStartKey))
    }

    // MARK: - Sign-Out Flow

    func testSignOutResetsEscalationAndStopsBlocking() {
        let task = TestFactories.makeSampleTask(id: 1)
        sut.taskBecameOverdue(task)
        XCTAssertTrue(sut.isInGracePeriod)

        // Simulate sign-out: resetAll called before clearing auth
        sut.resetAll()

        XCTAssertTrue(sut.overdueTaskIds.isEmpty)
        XCTAssertFalse(sut.isInGracePeriod)
        XCTAssertNil(sut.gracePeriodEndTime)
        XCTAssertTrue(mockScreenTime.stopBlockingCalled)
    }

    // MARK: - Idempotency

    func testDuplicateOverdueCallsAreIdempotent() {
        let task = TestFactories.makeSampleTask(id: 1)

        sut.taskBecameOverdue(task)
        sut.taskBecameOverdue(task)
        sut.taskBecameOverdue(task)

        XCTAssertEqual(sut.overdueTaskIds.count, 1)
    }

    func testCompletingNonTrackedTaskIsNoOp() {
        // Completing a task that was never overdue should not crash or affect state
        sut.taskCompleted(999)
        XCTAssertTrue(sut.overdueTaskIds.isEmpty)
    }

    // MARK: - Grace Period Info

    func testGracePeriodRemainingAvailableDuringGracePeriod() {
        let task = TestFactories.makeSampleTask(id: 1)
        sut.taskBecameOverdue(task)

        XCTAssertTrue(sut.isInGracePeriod)
        XCTAssertNotNil(sut.gracePeriodRemaining)
        XCTAssertNotNil(sut.gracePeriodRemainingFormatted)
        XCTAssertTrue(sut.gracePeriodRemaining! > 0)
    }

    func testGracePeriodRemainingNilAfterReset() {
        let task = TestFactories.makeSampleTask(id: 1)
        sut.taskBecameOverdue(task)
        sut.resetAll()

        XCTAssertNil(sut.gracePeriodRemaining)
        XCTAssertNil(sut.gracePeriodRemainingFormatted)
    }

    func testIsTaskTrackedReturnsTrueForOverdueTask() {
        let task = TestFactories.makeSampleTask(id: 7)
        sut.taskBecameOverdue(task)

        XCTAssertTrue(sut.isTaskTracked(7))
        XCTAssertFalse(sut.isTaskTracked(8))
    }

    func testIsTaskTrackedReturnsFalseAfterCompletion() {
        let task = TestFactories.makeSampleTask(id: 7)
        sut.taskBecameOverdue(task)
        sut.taskCompleted(7)

        XCTAssertFalse(sut.isTaskTracked(7))
    }
}
