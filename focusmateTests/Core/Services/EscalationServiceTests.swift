@testable import focusmate
import XCTest

@MainActor
final class EscalationServiceTests: XCTestCase {
  private var sut: EscalationService!
  private var mockScreenTime: MockScreenTimeService!

  private let gracePeriodStartKey = SharedDefaults.gracePeriodStartTimeKey
  private let overdueTaskIdsKey = SharedDefaults.overdueTaskIdsKey

  override func setUp() {
    super.setUp()
    // Clear persisted state before creating service (loadState reads these on init)
    SharedDefaults.store.removeObject(forKey: self.gracePeriodStartKey)
    SharedDefaults.store.removeObject(forKey: self.overdueTaskIdsKey)
    self.mockScreenTime = MockScreenTimeService()
    self.sut = EscalationService(screenTimeService: self.mockScreenTime)
  }

  override func tearDown() {
    self.sut.resetAll()
    SharedDefaults.store.removeObject(forKey: self.gracePeriodStartKey)
    SharedDefaults.store.removeObject(forKey: self.overdueTaskIdsKey)
    super.tearDown()
  }

  // MARK: - resetAll

  func testResetAllClearsGracePeriod() {
    // Manually set state then reset
    self.sut.resetAll()
    XCTAssertFalse(self.sut.isInGracePeriod)
    XCTAssertNil(self.sut.gracePeriodEndTime)
  }

  func testResetAllClearsOverdueTaskIds() {
    let task = TestFactories.makeSampleTask(id: 42)
    self.sut.taskBecameOverdue(task)
    XCTAssertFalse(self.sut.overdueTaskIds.isEmpty)

    self.sut.resetAll()
    XCTAssertTrue(self.sut.overdueTaskIds.isEmpty)
  }

  func testResetAllClearsPersistedState() {
    let task = TestFactories.makeSampleTask(id: 10)
    self.sut.taskBecameOverdue(task)

    self.sut.resetAll()

    let persistedIds = SharedDefaults.store.array(forKey: self.overdueTaskIdsKey) as? [Int]
    XCTAssertTrue(persistedIds?.isEmpty ?? true)
  }

  // MARK: - taskBecameOverdue

  func testTaskBecameOverdueAddsTaskId() {
    let task = TestFactories.makeSampleTask(id: 5)
    self.sut.taskBecameOverdue(task)
    XCTAssertTrue(self.sut.overdueTaskIds.contains(5))
  }

  func testTaskBecameOverdueDoesNotAddDuplicate() {
    let task = TestFactories.makeSampleTask(id: 5)
    self.sut.taskBecameOverdue(task)
    self.sut.taskBecameOverdue(task)
    XCTAssertEqual(self.sut.overdueTaskIds.count, 1)
  }

  func testTaskBecameOverdueDoesNotStartGracePeriodWhenNotAuthorized() {
    self.mockScreenTime.isAuthorized = false
    let task = TestFactories.makeSampleTask(id: 5)
    self.sut.taskBecameOverdue(task)

    // Grace period should NOT start because mock ScreenTime is not authorized
    XCTAssertFalse(self.sut.isInGracePeriod)
    XCTAssertNil(self.sut.gracePeriodEndTime)
  }

  func testTaskBecameOverduePersistsIds() {
    let task = TestFactories.makeSampleTask(id: 15)
    self.sut.taskBecameOverdue(task)

    let persistedIds = SharedDefaults.store.array(forKey: self.overdueTaskIdsKey) as? [Int]
    XCTAssertNotNil(persistedIds)
    XCTAssertTrue(persistedIds?.contains(15) ?? false)
  }

  // MARK: - taskCompleted

  func testTaskCompletedRemovesId() {
    let task = TestFactories.makeSampleTask(id: 8)
    self.sut.taskBecameOverdue(task)
    XCTAssertTrue(self.sut.overdueTaskIds.contains(8))

    self.sut.taskCompleted(8)
    XCTAssertFalse(self.sut.overdueTaskIds.contains(8))
  }

  func testTaskCompletedStopsEscalationWhenLastTask() {
    let task = TestFactories.makeSampleTask(id: 8)
    self.sut.taskBecameOverdue(task)

    self.sut.taskCompleted(8)

    XCTAssertTrue(self.sut.overdueTaskIds.isEmpty)
    XCTAssertFalse(self.sut.isInGracePeriod)
  }

  // MARK: - gracePeriodRemaining

  func testGracePeriodRemainingNilWhenNoGracePeriod() {
    XCTAssertNil(self.sut.gracePeriodRemaining)
  }

  func testGracePeriodRemainingFormattedNilWhenNoGracePeriod() {
    XCTAssertNil(self.sut.gracePeriodRemainingFormatted)
  }

  // MARK: - checkAuthorizationRevocation

  func testCheckAuthorizationRevocationResetsWhenUnauthorized() {
    // Start escalation with authorization
    let task = TestFactories.makeSampleTask(id: 99)
    self.sut.taskBecameOverdue(task)
    XCTAssertFalse(self.sut.overdueTaskIds.isEmpty)

    // Simulate user revoking Screen Time in iOS Settings
    self.mockScreenTime.isAuthorized = false

    self.sut.checkAuthorizationRevocation()

    // Escalation state should be fully reset
    XCTAssertTrue(self.sut.overdueTaskIds.isEmpty)
    XCTAssertFalse(self.sut.isInGracePeriod)
    XCTAssertTrue(self.mockScreenTime.stopBlockingCalled)
  }

  func testCheckAuthorizationRevocationNoOpWhenStillAuthorized() {
    let task = TestFactories.makeSampleTask(id: 99)
    self.sut.taskBecameOverdue(task)

    // Authorization still granted — should not reset
    self.sut.checkAuthorizationRevocation()

    XCTAssertTrue(self.sut.overdueTaskIds.contains(99))
  }

  func testCheckAuthorizationRevocationNoOpWhenNoActiveEscalation() {
    self.mockScreenTime.isAuthorized = false

    // No overdue tasks — nothing to revoke
    self.sut.checkAuthorizationRevocation()

    XCTAssertTrue(self.sut.overdueTaskIds.isEmpty)
    XCTAssertFalse(self.mockScreenTime.stopBlockingCalled)
  }

  // MARK: - authorizationWasRevoked flag

  func testCheckAuthorizationRevocationSetsRevokedFlag() {
    let task = TestFactories.makeSampleTask(id: 50)
    self.sut.taskBecameOverdue(task)

    self.mockScreenTime.isAuthorized = false
    self.sut.checkAuthorizationRevocation()

    // Flag should be set so the UI can show a recovery banner
    XCTAssertTrue(self.sut.authorizationWasRevoked)
  }

  func testResetAllDoesNotClearRevokedFlag() {
    // Set the flag, then reset — flag must survive for the banner to display
    let task = TestFactories.makeSampleTask(id: 51)
    self.sut.taskBecameOverdue(task)
    self.mockScreenTime.isAuthorized = false
    self.sut.checkAuthorizationRevocation()
    XCTAssertTrue(self.sut.authorizationWasRevoked)

    // resetAll should NOT clear authorizationWasRevoked
    self.sut.resetAll()
    XCTAssertTrue(self.sut.authorizationWasRevoked)
  }

  func testClearAuthorizationRevocationFlagClearsFlag() {
    let task = TestFactories.makeSampleTask(id: 52)
    self.sut.taskBecameOverdue(task)
    self.mockScreenTime.isAuthorized = false
    self.sut.checkAuthorizationRevocation()
    XCTAssertTrue(self.sut.authorizationWasRevoked)

    self.sut.clearAuthorizationRevocationFlag()
    XCTAssertFalse(self.sut.authorizationWasRevoked)
  }

  func testCheckAuthorizationRevocationAutoClearsWhenReauthorized() {
    // Simulate: revocation detected → user re-grants in iOS Settings → app foregrounds
    let task = TestFactories.makeSampleTask(id: 53)
    self.sut.taskBecameOverdue(task)
    self.mockScreenTime.isAuthorized = false
    self.sut.checkAuthorizationRevocation()
    XCTAssertTrue(self.sut.authorizationWasRevoked)

    // User re-grants authorization
    self.mockScreenTime.isAuthorized = true
    self.sut.checkAuthorizationRevocation()

    // Flag should auto-clear because the user fixed the problem
    XCTAssertFalse(self.sut.authorizationWasRevoked)
  }
}
