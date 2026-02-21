@testable import focusmate
import XCTest

final class MutationQueueTests: XCTestCase {
  private var sut: MutationQueue!

  override func setUp() {
    super.setUp()
    self.sut = MutationQueue()
  }

  override func tearDown() async throws {
    await self.sut.clearAll()
    self.sut = nil
    try await super.tearDown()
  }

  // MARK: - Enqueue

  func testEnqueueIncrementsPendingCount() async {
    await self.sut.enqueue(description: "task-1") {}
    let count = await sut.pendingCount
    XCTAssertEqual(count, 1)
  }

  func testEnqueueMultipleIncrementsPendingCount() async {
    await self.sut.enqueue(description: "task-1") {}
    await self.sut.enqueue(description: "task-2") {}
    await self.sut.enqueue(description: "task-3") {}
    let count = await sut.pendingCount
    XCTAssertEqual(count, 3)
  }

  // MARK: - Flush Success

  func testFlushExecutesAllOperationsInOrder() async {
    var executionOrder: [Int] = []

    await sut.enqueue(description: "op-1") { executionOrder.append(1) }
    await self.sut.enqueue(description: "op-2") { executionOrder.append(2) }
    await self.sut.enqueue(description: "op-3") { executionOrder.append(3) }

    await self.sut.flush()

    XCTAssertEqual(executionOrder, [1, 2, 3])
    let count = await sut.pendingCount
    XCTAssertEqual(count, 0)
  }

  func testFlushClearsQueueOnSuccess() async {
    await self.sut.enqueue(description: "op-1") {}
    await self.sut.enqueue(description: "op-2") {}

    await self.sut.flush()

    let count = await sut.pendingCount
    XCTAssertEqual(count, 0)
  }

  func testFlushIsNoOpWhenQueueIsEmpty() async {
    // Should not crash or hang
    await self.sut.flush()
    let count = await sut.pendingCount
    XCTAssertEqual(count, 0)
  }

  // MARK: - Flush Offline Stop

  func testFlushStopsOnOfflineError() async {
    var executed: [String] = []

    await sut.enqueue(description: "op-1") { executed.append("op-1") }
    await self.sut.enqueue(description: "op-2-offline") {
      executed.append("op-2")
      throw APIError.noInternetConnection
    }
    await self.sut.enqueue(description: "op-3") { executed.append("op-3") }

    await self.sut.flush()

    // op-1 succeeded, op-2 threw offline, op-3 never reached
    XCTAssertEqual(executed, ["op-1", "op-2"])
    // op-1 removed (succeeded), op-2 and op-3 remain
    let count = await sut.pendingCount
    XCTAssertEqual(count, 2)
  }

  func testFlushStopsOnNetworkConnectionLostError() async {
    var executed: [String] = []
    let urlError = URLError(.networkConnectionLost)

    await sut.enqueue(description: "op-1") { executed.append("op-1") }
    await self.sut.enqueue(description: "op-2-lost") {
      executed.append("op-2")
      throw APIError.network(urlError)
    }
    await self.sut.enqueue(description: "op-3") { executed.append("op-3") }

    await self.sut.flush()

    XCTAssertEqual(executed, ["op-1", "op-2"])
    let count = await sut.pendingCount
    XCTAssertEqual(count, 2)
  }

  func testFlushPreservesMutationsAfterOfflineStop() async {
    // Enqueue 3 mutations, second goes offline on first attempt
    var op2CallCount = 0

    await sut.enqueue(description: "op-1") {}
    await self.sut.enqueue(description: "op-2-flaky") {
      op2CallCount += 1
      if op2CallCount == 1 { throw APIError.noInternetConnection }
    }
    await self.sut.enqueue(description: "op-3") {}

    await self.sut.flush()

    // First flush: op-1 done, op-2 offline (stop), op-3 never ran
    let countAfterFirst = await sut.pendingCount
    XCTAssertEqual(countAfterFirst, 2)

    // Second flush (simulating reconnect): op-2 succeeds now, op-3 runs
    await self.sut.flush()

    let countAfterSecond = await sut.pendingCount
    XCTAssertEqual(countAfterSecond, 0)
  }

  // MARK: - Retry and Drop

  func testNonOfflineFailureIncrementsRetryCount() async {
    var callCount = 0

    await sut.enqueue(description: "flaky") {
      callCount += 1
      throw APIError.serverError(500, "Internal Server Error", nil)
    }

    // First flush: retry count becomes 1
    await self.sut.flush()
    XCTAssertEqual(callCount, 1)
    let countAfter1 = await sut.pendingCount
    XCTAssertEqual(countAfter1, 1, "Should keep mutation after 1 failure")

    // Second flush: retry count becomes 2
    await self.sut.flush()
    XCTAssertEqual(callCount, 2)
    let countAfter2 = await sut.pendingCount
    XCTAssertEqual(countAfter2, 1, "Should keep mutation after 2 failures")

    // Third flush: retry count reaches maxRetries (3), mutation dropped
    await self.sut.flush()
    XCTAssertEqual(callCount, 3)
    let countAfter3 = await sut.pendingCount
    XCTAssertEqual(countAfter3, 0, "Should drop mutation after 3 failures")
  }

  func testMixedSuccessAndFailureFlush() async {
    var executed: [String] = []

    await sut.enqueue(description: "success-1") { executed.append("success-1") }
    await self.sut.enqueue(description: "always-fails") {
      executed.append("fail")
      throw APIError.badStatus(400, "Bad Request", nil)
    }
    await self.sut.enqueue(description: "success-2") { executed.append("success-2") }

    await self.sut.flush()

    // All three execute (non-offline errors don't stop the flush)
    XCTAssertEqual(executed, ["success-1", "fail", "success-2"])
    // success-1 and success-2 removed, always-fails retained (1 retry)
    let count = await sut.pendingCount
    XCTAssertEqual(count, 1)
  }

  func testDroppedMutationDoesNotBlockOthers() async {
    var failCallCount = 0

    await sut.enqueue(description: "fail-then-drop") {
      failCallCount += 1
      throw APIError.badStatus(422, "Unprocessable", nil)
    }
    await self.sut.enqueue(description: "always-succeeds") {}

    // Flush 3 times to exhaust retries
    for _ in 0 ..< 3 {
      await self.sut.flush()
    }

    XCTAssertEqual(failCallCount, 3)
    let count = await sut.pendingCount
    XCTAssertEqual(count, 0, "Both mutations should be gone after 3 flushes")
  }

  // MARK: - Re-entrancy Guard

  func testFlushIsNoOpWhenCalledRecursivelyDuringFlush() async {
    var executionOrder: [Int] = []

    // First mutation calls flush() re-entrantly — the nested call should hit
    // the `isFlushing` guard and return immediately (no deadlock, no double-exec).
    await sut.enqueue(description: "op-1-reentrant") { [sut] in
      executionOrder.append(1)
      await sut!.flush() // re-entrant: isFlushing == true → early return
    }
    await self.sut.enqueue(description: "op-2") { executionOrder.append(2) }

    await self.sut.flush()

    // The outer flush runs both mutations sequentially. The nested flush() is a no-op.
    XCTAssertEqual(executionOrder, [1, 2])
    let count = await sut.pendingCount
    XCTAssertEqual(count, 0, "Queue should be empty — outer flush processed both mutations")
  }

  // MARK: - clearAll

  func testClearAllRemovesAllPending() async {
    await self.sut.enqueue(description: "op-1") {}
    await self.sut.enqueue(description: "op-2") {}
    await self.sut.enqueue(description: "op-3") {}

    let countBefore = await sut.pendingCount
    XCTAssertEqual(countBefore, 3)

    await self.sut.clearAll()

    let countAfter = await sut.pendingCount
    XCTAssertEqual(countAfter, 0)
  }

  func testClearAllPreventsFlushFromExecuting() async {
    var executed = false

    await sut.enqueue(description: "should-not-run") { executed = true }
    await self.sut.clearAll()
    await self.sut.flush()

    XCTAssertFalse(executed)
  }
}
