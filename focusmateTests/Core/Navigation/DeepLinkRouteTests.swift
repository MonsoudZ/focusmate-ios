import XCTest
@testable import focusmate

final class DeepLinkRouteTests: XCTestCase {

    // MARK: - Push Notification Parsing Tests

    func testParseNudgeNotificationWithIntTaskId() {
        let userInfo: [AnyHashable: Any] = [
            "type": "nudge",
            "task_id": 123
        ]

        let route = DeepLinkRoute(pushNotificationUserInfo: userInfo)

        XCTAssertEqual(route, .openTask(taskId: 123))
    }

    func testParseNudgeNotificationWithStringTaskId() {
        let userInfo: [AnyHashable: Any] = [
            "type": "nudge",
            "task_id": "456"
        ]

        let route = DeepLinkRoute(pushNotificationUserInfo: userInfo)

        XCTAssertEqual(route, .openTask(taskId: 456))
    }

    func testParseNudgeNotificationWithoutTaskIdReturnsNil() {
        let userInfo: [AnyHashable: Any] = [
            "type": "nudge"
        ]

        let route = DeepLinkRoute(pushNotificationUserInfo: userInfo)

        XCTAssertNil(route)
    }

    func testParseNotificationWithoutTypeReturnsNil() {
        let userInfo: [AnyHashable: Any] = [
            "task_id": 123
        ]

        let route = DeepLinkRoute(pushNotificationUserInfo: userInfo)

        XCTAssertNil(route)
    }

    func testParseUnknownNotificationTypeReturnsNil() {
        let userInfo: [AnyHashable: Any] = [
            "type": "unknown_type",
            "task_id": 123
        ]

        let route = DeepLinkRoute(pushNotificationUserInfo: userInfo)

        XCTAssertNil(route)
    }

    func testParseEmptyNotificationReturnsNil() {
        let userInfo: [AnyHashable: Any] = [:]

        let route = DeepLinkRoute(pushNotificationUserInfo: userInfo)

        XCTAssertNil(route)
    }

    // MARK: - Local Notification Parsing Tests

    func testParseMorningBriefingNotification() {
        let route = DeepLinkRoute(localNotificationIdentifier: "morning-briefing")

        XCTAssertEqual(route, .openToday)
    }

    func testParseTaskNotification() {
        let route = DeepLinkRoute(localNotificationIdentifier: "task-789")

        XCTAssertEqual(route, .openTask(taskId: 789))
    }

    func testParseTaskNotificationWithLargeId() {
        let route = DeepLinkRoute(localNotificationIdentifier: "task-999999")

        XCTAssertEqual(route, .openTask(taskId: 999999))
    }

    func testParseTaskNotificationWithInvalidIdReturnsNil() {
        let route = DeepLinkRoute(localNotificationIdentifier: "task-abc")

        XCTAssertNil(route)
    }

    func testParseTaskNotificationWithSuffix() {
        let route = DeepLinkRoute(localNotificationIdentifier: "task-42-due-soon")

        XCTAssertEqual(route, .openTask(taskId: 42))
    }

    func testParseEscalationStartNotification() {
        let route = DeepLinkRoute(localNotificationIdentifier: "escalation-55-start")

        XCTAssertEqual(route, .openTask(taskId: 55))
    }

    func testParseEscalationWarningNotification() {
        let route = DeepLinkRoute(localNotificationIdentifier: "escalation-101-warning")

        XCTAssertEqual(route, .openTask(taskId: 101))
    }

    func testParseEscalationBlockingStartedNotification() {
        let route = DeepLinkRoute(localNotificationIdentifier: "escalation-blocking-started")

        XCTAssertEqual(route, .openToday)
    }

    func testParseEscalationBlockingSkippedNotification() {
        let route = DeepLinkRoute(localNotificationIdentifier: "escalation-blocking-skipped")

        XCTAssertEqual(route, .openToday)
    }

    func testParseUnknownLocalNotificationReturnsNil() {
        let route = DeepLinkRoute(localNotificationIdentifier: "some-random-id")

        XCTAssertNil(route)
    }

    func testParseEmptyLocalNotificationReturnsNil() {
        let route = DeepLinkRoute(localNotificationIdentifier: "")

        XCTAssertNil(route)
    }

    // MARK: - URL Parsing Tests

    func testParseInviteURLWithCustomScheme() {
        let url = URL(string: "focusmate://invite/ABC123")!

        let route = DeepLinkRoute(url: url)

        XCTAssertEqual(route, .openInvite(code: "ABC123"))
    }

    func testParseInviteURLWithHttpsScheme() {
        let url = URL(string: "https://focusmate.app/invite/XYZ789")!

        let route = DeepLinkRoute(url: url)

        XCTAssertEqual(route, .openInvite(code: "XYZ789"))
    }

    func testParseInviteURLWithHttpScheme() {
        let url = URL(string: "http://focusmate.app/invite/CODE456")!

        let route = DeepLinkRoute(url: url)

        XCTAssertEqual(route, .openInvite(code: "CODE456"))
    }

    func testParseInviteURLWithLongCode() {
        let url = URL(string: "focusmate://invite/ABCDEFGHIJKLMNOP123456")!

        let route = DeepLinkRoute(url: url)

        XCTAssertEqual(route, .openInvite(code: "ABCDEFGHIJKLMNOP123456"))
    }

    func testParseTaskURLWithCustomScheme() {
        let url = URL(string: "focusmate://task/42")!

        let route = DeepLinkRoute(url: url)

        XCTAssertEqual(route, .openTask(taskId: 42))
    }

    func testParseTaskURLWithHttpsScheme() {
        let url = URL(string: "https://focusmate.app/task/99")!

        let route = DeepLinkRoute(url: url)

        XCTAssertEqual(route, .openTask(taskId: 99))
    }

    func testParseTaskURLWithLargeId() {
        let url = URL(string: "focusmate://task/999999")!

        let route = DeepLinkRoute(url: url)

        XCTAssertEqual(route, .openTask(taskId: 999999))
    }

    func testParseTaskURLWithNonNumericIdReturnsNil() {
        let url = URL(string: "focusmate://task/abc")!

        let route = DeepLinkRoute(url: url)

        XCTAssertNil(route)
    }

    func testParseURLWithoutInvitePathReturnsNil() {
        let url = URL(string: "focusmate://home")!

        let route = DeepLinkRoute(url: url)

        XCTAssertNil(route)
    }

    func testParseInviteURLWithoutCodeReturnsNil() {
        let url = URL(string: "focusmate://invite/")!

        let route = DeepLinkRoute(url: url)

        XCTAssertNil(route)
    }

    func testParseURLWithDifferentPathReturnsNil() {
        let url = URL(string: "focusmate://settings/notifications")!

        let route = DeepLinkRoute(url: url)

        XCTAssertNil(route)
    }

    // MARK: - Equatable Tests

    func testOpenTodayEquality() {
        let route1 = DeepLinkRoute.openToday
        let route2 = DeepLinkRoute.openToday

        XCTAssertEqual(route1, route2)
    }

    func testOpenTaskEquality() {
        let route1 = DeepLinkRoute.openTask(taskId: 123)
        let route2 = DeepLinkRoute.openTask(taskId: 123)

        XCTAssertEqual(route1, route2)
    }

    func testOpenTaskInequality() {
        let route1 = DeepLinkRoute.openTask(taskId: 123)
        let route2 = DeepLinkRoute.openTask(taskId: 456)

        XCTAssertNotEqual(route1, route2)
    }

    func testOpenInviteEquality() {
        let route1 = DeepLinkRoute.openInvite(code: "ABC")
        let route2 = DeepLinkRoute.openInvite(code: "ABC")

        XCTAssertEqual(route1, route2)
    }

    func testOpenInviteInequality() {
        let route1 = DeepLinkRoute.openInvite(code: "ABC")
        let route2 = DeepLinkRoute.openInvite(code: "XYZ")

        XCTAssertNotEqual(route1, route2)
    }

    func testDifferentRouteTypesNotEqual() {
        let route1 = DeepLinkRoute.openToday
        let route2 = DeepLinkRoute.openTask(taskId: 1)
        let route3 = DeepLinkRoute.openInvite(code: "ABC")

        XCTAssertNotEqual(route1, route2)
        XCTAssertNotEqual(route2, route3)
        XCTAssertNotEqual(route1, route3)
    }
}
