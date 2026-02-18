import XCTest
@testable import focusmate

final class MutationQueueTests: XCTestCase {

    private var sut: MutationQueue!

    override func setUp() {
        super.setUp()
        sut = MutationQueue()
    }

    override func tearDown() async throws {
        await sut.clearAll()
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Enqueue

    func testEnqueueIncrementsPendingCount() async {
        await sut.enqueue(description: "task-1") {}
        let count = await sut.pendingCount
        XCTAssertEqual(count, 1)
    }

    func testEnqueueMultipleIncrementsPendingCount() async {
        await sut.enqueue(description: "task-1") {}
        await sut.enqueue(description: "task-2") {}
        await sut.enqueue(description: "task-3") {}
        let count = await sut.pendingCount
        XCTAssertEqual(count, 3)
    }

    // MARK: - Flush Success

    func testFlushExecutesAllOperationsInOrder() async {
        var executionOrder: [Int] = []

        await sut.enqueue(description: "op-1") { executionOrder.append(1) }
        await sut.enqueue(description: "op-2") { executionOrder.append(2) }
        await sut.enqueue(description: "op-3") { executionOrder.append(3) }

        await sut.flush()

        XCTAssertEqual(executionOrder, [1, 2, 3])
        let count = await sut.pendingCount
        XCTAssertEqual(count, 0)
    }

    func testFlushClearsQueueOnSuccess() async {
        await sut.enqueue(description: "op-1") {}
        await sut.enqueue(description: "op-2") {}

        await sut.flush()

        let count = await sut.pendingCount
        XCTAssertEqual(count, 0)
    }

    func testFlushIsNoOpWhenQueueIsEmpty() async {
        // Should not crash or hang
        await sut.flush()
        let count = await sut.pendingCount
        XCTAssertEqual(count, 0)
    }

    // MARK: - Flush Offline Stop

    func testFlushStopsOnOfflineError() async {
        var executed: [String] = []

        await sut.enqueue(description: "op-1") { executed.append("op-1") }
        await sut.enqueue(description: "op-2-offline") {
            executed.append("op-2")
            throw APIError.noInternetConnection
        }
        await sut.enqueue(description: "op-3") { executed.append("op-3") }

        await sut.flush()

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
        await sut.enqueue(description: "op-2-lost") {
            executed.append("op-2")
            throw APIError.network(urlError)
        }
        await sut.enqueue(description: "op-3") { executed.append("op-3") }

        await sut.flush()

        XCTAssertEqual(executed, ["op-1", "op-2"])
        let count = await sut.pendingCount
        XCTAssertEqual(count, 2)
    }

    func testFlushPreservesMutationsAfterOfflineStop() async {
        // Enqueue 3 mutations, second goes offline on first attempt
        var op2CallCount = 0

        await sut.enqueue(description: "op-1") {}
        await sut.enqueue(description: "op-2-flaky") {
            op2CallCount += 1
            if op2CallCount == 1 { throw APIError.noInternetConnection }
        }
        await sut.enqueue(description: "op-3") {}

        await sut.flush()

        // First flush: op-1 done, op-2 offline (stop), op-3 never ran
        let countAfterFirst = await sut.pendingCount
        XCTAssertEqual(countAfterFirst, 2)

        // Second flush (simulating reconnect): op-2 succeeds now, op-3 runs
        await sut.flush()

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
        await sut.flush()
        XCTAssertEqual(callCount, 1)
        let countAfter1 = await sut.pendingCount
        XCTAssertEqual(countAfter1, 1, "Should keep mutation after 1 failure")

        // Second flush: retry count becomes 2
        await sut.flush()
        XCTAssertEqual(callCount, 2)
        let countAfter2 = await sut.pendingCount
        XCTAssertEqual(countAfter2, 1, "Should keep mutation after 2 failures")

        // Third flush: retry count reaches maxRetries (3), mutation dropped
        await sut.flush()
        XCTAssertEqual(callCount, 3)
        let countAfter3 = await sut.pendingCount
        XCTAssertEqual(countAfter3, 0, "Should drop mutation after 3 failures")
    }

    func testMixedSuccessAndFailureFlush() async {
        var executed: [String] = []

        await sut.enqueue(description: "success-1") { executed.append("success-1") }
        await sut.enqueue(description: "always-fails") {
            executed.append("fail")
            throw APIError.badStatus(400, "Bad Request", nil)
        }
        await sut.enqueue(description: "success-2") { executed.append("success-2") }

        await sut.flush()

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
        await sut.enqueue(description: "always-succeeds") {}

        // Flush 3 times to exhaust retries
        for _ in 0..<3 {
            await sut.flush()
        }

        XCTAssertEqual(failCallCount, 3)
        let count = await sut.pendingCount
        XCTAssertEqual(count, 0, "Both mutations should be gone after 3 flushes")
    }

    // MARK: - clearAll

    func testClearAllRemovesAllPending() async {
        await sut.enqueue(description: "op-1") {}
        await sut.enqueue(description: "op-2") {}
        await sut.enqueue(description: "op-3") {}

        let countBefore = await sut.pendingCount
        XCTAssertEqual(countBefore, 3)

        await sut.clearAll()

        let countAfter = await sut.pendingCount
        XCTAssertEqual(countAfter, 0)
    }

    func testClearAllPreventsFlushFromExecuting() async {
        var executed = false

        await sut.enqueue(description: "should-not-run") { executed = true }
        await sut.clearAll()
        await sut.flush()

        XCTAssertFalse(executed)
    }
}
