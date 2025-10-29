import XCTest
@testable import focusmate

final class APISmokeTest: XCTestCase {
    func testAPISmoke() async throws {
        let session = AuthSession()
        let client = NewAPIClient(auth: session)
        let authAPI = AuthAPI(api: client, session: session)
        let lists = ListsRepo(api: client)
        let tasks = TasksRepo(api: client)

        // This is a smoke test - adjust credentials as needed
        let user = try await authAPI.signIn(email: "iosuser@example.com", password: "password123")
        XCTAssertNotNil(user.id)
        
        let list = try await lists.create(title: "Test Inbox")
        XCTAssertEqual(list.title, "Test Inbox")
        
        let task = try await tasks.create(listId: list.id, title: "First task")
        XCTAssertEqual(task.title, "First task")
        
        let completedTask = try await tasks.complete(listId: list.id, id: task.id, done: true)
        XCTAssertNotNil(completedTask.completed_at)
        
        try await tasks.destroy(listId: list.id, id: task.id)
        try await lists.destroy(id: list.id)
        
        await authAPI.signOut()
    }
}
