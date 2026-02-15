import XCTest
@testable import focusmate

@MainActor
final class EscalationServiceTests: XCTestCase {

    private var sut: EscalationService!
    private var mockScreenTime: MockScreenTimeService!

    private let gracePeriodStartKey = "Escalation_GracePeriodStart"
    private let overdueTaskIdsKey = "Escalation_OverdueTaskIds"

    override func setUp() {
        super.setUp()
        // Clear persisted state before creating service (loadState reads these on init)
        UserDefaults.standard.removeObject(forKey: gracePeriodStartKey)
        UserDefaults.standard.removeObject(forKey: overdueTaskIdsKey)
        mockScreenTime = MockScreenTimeService()
        sut = EscalationService(screenTimeService: mockScreenTime)
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
        mockScreenTime.isAuthorized = false
        let task = TestFactories.makeSampleTask(id: 5)
        sut.taskBecameOverdue(task)

        // Grace period should NOT start because mock ScreenTime is not authorized
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

    // MARK: - checkAuthorizationRevocation

    func testCheckAuthorizationRevocationResetsWhenUnauthorized() {
        // Start escalation with authorization
        let task = TestFactories.makeSampleTask(id: 99)
        sut.taskBecameOverdue(task)
        XCTAssertFalse(sut.overdueTaskIds.isEmpty)

        // Simulate user revoking Screen Time in iOS Settings
        mockScreenTime.isAuthorized = false

        sut.checkAuthorizationRevocation()

        // Escalation state should be fully reset
        XCTAssertTrue(sut.overdueTaskIds.isEmpty)
        XCTAssertFalse(sut.isInGracePeriod)
        XCTAssertTrue(mockScreenTime.stopBlockingCalled)
    }

    func testCheckAuthorizationRevocationNoOpWhenStillAuthorized() {
        let task = TestFactories.makeSampleTask(id: 99)
        sut.taskBecameOverdue(task)

        // Authorization still granted — should not reset
        sut.checkAuthorizationRevocation()

        XCTAssertTrue(sut.overdueTaskIds.contains(99))
    }

    func testCheckAuthorizationRevocationNoOpWhenNoActiveEscalation() {
        mockScreenTime.isAuthorized = false

        // No overdue tasks — nothing to revoke
        sut.checkAuthorizationRevocation()

        XCTAssertTrue(sut.overdueTaskIds.isEmpty)
        XCTAssertFalse(mockScreenTime.stopBlockingCalled)
    }

    // MARK: - authorizationWasRevoked flag

    func testCheckAuthorizationRevocationSetsRevokedFlag() {
        let task = TestFactories.makeSampleTask(id: 50)
        sut.taskBecameOverdue(task)

        mockScreenTime.isAuthorized = false
        sut.checkAuthorizationRevocation()

        // Flag should be set so the UI can show a recovery banner
        XCTAssertTrue(sut.authorizationWasRevoked)
    }

    func testResetAllDoesNotClearRevokedFlag() {
        // Set the flag, then reset — flag must survive for the banner to display
        let task = TestFactories.makeSampleTask(id: 51)
        sut.taskBecameOverdue(task)
        mockScreenTime.isAuthorized = false
        sut.checkAuthorizationRevocation()
        XCTAssertTrue(sut.authorizationWasRevoked)

        // resetAll should NOT clear authorizationWasRevoked
        sut.resetAll()
        XCTAssertTrue(sut.authorizationWasRevoked)
    }

    func testClearAuthorizationRevocationFlagClearsFlag() {
        let task = TestFactories.makeSampleTask(id: 52)
        sut.taskBecameOverdue(task)
        mockScreenTime.isAuthorized = false
        sut.checkAuthorizationRevocation()
        XCTAssertTrue(sut.authorizationWasRevoked)

        sut.clearAuthorizationRevocationFlag()
        XCTAssertFalse(sut.authorizationWasRevoked)
    }

    func testCheckAuthorizationRevocationAutoClearsWhenReauthorized() {
        // Simulate: revocation detected → user re-grants in iOS Settings → app foregrounds
        let task = TestFactories.makeSampleTask(id: 53)
        sut.taskBecameOverdue(task)
        mockScreenTime.isAuthorized = false
        sut.checkAuthorizationRevocation()
        XCTAssertTrue(sut.authorizationWasRevoked)

        // User re-grants authorization
        mockScreenTime.isAuthorized = true
        sut.checkAuthorizationRevocation()

        // Flag should auto-clear because the user fixed the problem
        XCTAssertFalse(sut.authorizationWasRevoked)
    }
}
